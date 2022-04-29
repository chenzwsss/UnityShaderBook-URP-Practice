Shader "URP Practice/Chapter 9/Shadow"
{
    Properties
    {
        _Diffuse("Diffuse", Color) = (1, 1, 1, 1)
        _Specular("Specular", Color) = (1, 1, 1, 1)
        _Gloss("Gloss", Range(8.0, 256)) = 20
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
            half4 _Diffuse;
            half4 _Specular;
            half _Gloss;
        CBUFFER_END

        ENDHLSL

        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM

            // 接收阴影所需关键字
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _SHADOWS_SOFT // 软阴影

            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 staticLightmapUV : TEXCOORD1;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float2 staticLightmapUV : TEXCOORD2;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;

                output.positionHCS  = TransformObjectToHClip(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);

                OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);

                return output;
            }

            // Light: (diffuse + specular) * distanceAttenuation * shadowAttenuation
            half3 LightingBased(Light light, half3 normalWS, half3 viewDirectionWS)
            {
                half3 lightDirectionWS = normalize(light.direction);
                half3 diffuse = light.color * _Diffuse.rgb * max(dot(normalWS, lightDirectionWS), 0.0);
                half3 halfDir = normalize(lightDirectionWS + viewDirectionWS);
                half3 specular = light.color * _Specular.rgb * pow(max(dot(normalWS, halfDir), 0.0), _Gloss);
                return (diffuse + specular) * light.distanceAttenuation * light.shadowAttenuation;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half3 normalWS = normalize(i.normalWS);
                half3 viewDirectionWS = normalize(GetWorldSpaceViewDir(i.positionWS));

                half4 shadowMask;
                #if defined(SHADOWS_SHADOWMASK) && defined(LIGHTMAP_ON)
                    shadowMask = SAMPLE_SHADOWMASK(i.staticLightmapUV);
                #elif !defined (LIGHTMAP_ON)
                    shadowMask = unity_ProbesOcclusion;
                #else
                    shadowMask = half4(1, 1, 1, 1);
                #endif

                // 获取阴影坐标
                float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);

                // 主光源数据
                Light mainLight = GetMainLight(shadowCoord);

                // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
                // MixRealtimeAndBakedGI(mainLight, i.normalWS, i.bakedGI);

                // 环境光
                half3 ambient = SampleSH(normalWS);

                // main light
                half3 baseLighting = LightingBased(mainLight, normalWS, viewDirectionWS);

                // 计算其他光源
                uint pixelLightCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0; lightIndex < pixelLightCount; ++lightIndex)
                {
                    Light light = GetAdditionalLight(lightIndex, i.positionWS, shadowMask);
                    baseLighting += LightingBased(light, normalWS, viewDirectionWS);
                }

                return half4(ambient + baseLighting, 1.0);
            }
            ENDHLSL
        }

        // 下面计算阴影的Pass可以直接通过使用URP内置的Pass计算
        // UsePass "Universal Render Pipeline/Lit/ShadowCaster"
        // or
        // 计算阴影的Pass
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }

            Cull Off
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM

            // 设置关键字
            #pragma shader_feature _ALPHATEST_ON
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float3 _LightDirection;
            float3 _LightPosition;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
            };

            // 获取裁剪空间下的阴影坐标
            float4 GetShadowPositionHClip(Attributes input)
            {
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS.xyz);

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                #else
                    float3 lightDirectionWS = _LightDirection;
                #endif

                // 获取阴影专用裁剪空间下的坐标
                float4 positionHCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

                // 判断是否是在DirectX平台翻转过坐标
                #if UNITY_REVERSED_Z
                    positionHCS.z = min(positionHCS.z, positionHCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    positionHCS.z = max(positionHCS.z, positionHCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif

                return positionHCS;
            }

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionHCS = GetShadowPositionHClip(input);
                return output;
            }

            half4 frag(Varyings input) : SV_TARGET
            {
                return 0;
            }

            ENDHLSL
        }
    }
    FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}
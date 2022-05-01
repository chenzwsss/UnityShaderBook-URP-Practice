Shader "URP Practice/Common/BumpedSpecular"
{
    Properties
    {
        // 基础纹理
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        // 法线纹理
        _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Bump Scale", Float) = 1.0
        // 漫反射叠加颜色
        _Diffuse("Diffuse", Color) = (1, 1, 1, 1)
        // 高光叠加颜色
        _Specular("Specular", Color) = (1, 1, 1, 1)
        // 高光系数
        _Gloss("Specular Gloss", Range(8.0, 256.0)) = 20.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" }

        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM

            // 开启接收主光源阴影
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            // 开启主光源阴影层级
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            // 开启软阴影
            #pragma multi_compile _ _SHADOWS_SOFT

            // 开启接收其他光源阴影
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _BumpMap_ST;
                half4 _Diffuse;
                half4 _Specular;
                half _BumpScale;
                half _Gloss;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 texcoord : TEXCOORD0;
                float2 lightmapUV : TEXCOORD1;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 uv : TEXCOORD0; // uv.xy: 基础纹理uv, uv.zw: 法线纹理uv
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 bitangentWS : TEXCOORD4;
                float2 lightmapUV : TEXCOORD5;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

                output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.uv.zw = TRANSFORM_TEX(input.texcoord, _BumpMap);

                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                // 法线 in WS
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                // 切线 in WS
                output.tangentWS = TransformObjectToWorld(input.tangentOS.xyz);
                // 通过世界空间下的法线和切线计算出副切线bitangent
                output.bitangentWS = cross(output.normalWS, output.tangentWS) * input.tangentOS.w;

                output.lightmapUV = input.lightmapUV * unity_LightmapST.xy + unity_LightmapST.zw;

                return output;
            }

            half3 LightingBased(Light light, half3 normalWS, half3 viewDirectionWS, half3 albedo)
            {
                half3 lightDirectionWS = normalize(light.direction);

                half3 diffuse = light.color * albedo * _Diffuse.rgb * saturate(dot(normalWS, lightDirectionWS));

                half3 halfDir = normalize(lightDirectionWS + viewDirectionWS);
                half3 specular = light.color * _Specular.rgb * pow(saturate(dot(normalWS, halfDir)), _Gloss);

                return (diffuse + specular) * light.distanceAttenuation * light.shadowAttenuation;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // 视线方向
                half3 viewDirectionWS = normalize(GetWorldSpaceViewDir(input.positionWS));
                // 采样法线贴图，得到切线空间下的法线向量
                half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv.zw), _BumpScale);
                // 组建切线空间矩阵
                half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz);
                // 把切线空间下的法线转换到世界空间下
                half3 normalWS = normalize(mul(normalTS, tangentToWorld));

                // 采样基础纹理
                half3 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv.xy).rgb * _BaseColor.rgb;

                // 采样阴影贴图
                half4 shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV);
                // 计算主光源阴影坐标
                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);

                // 计算主光源
                Light mainLight = GetMainLight(shadowCoord, input.positionWS, shadowMask);
                // 环境光照
                half3 ambient = SampleSH(normalWS) * albedo;

                half3 lightingBased = LightingBased(mainLight, normalWS, viewDirectionWS, albedo);

                uint pixelLightsCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0; lightIndex < pixelLightsCount; ++lightIndex)
                {
                    Light light = GetAdditionalLight(lightIndex, input.positionWS, shadowMask);
                    lightingBased += LightingBased(light, normalWS, viewDirectionWS, albedo);
                }

                return half4(ambient + lightingBased, 1.0);
            }

            ENDHLSL
        }
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }

            HLSLPROGRAM

            #pragma multi_compile _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
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
                float4 positionCS : SV_POSITION;
            };

            float4 GetShadowPositionHClip(Attributes input)
            {
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                #else
                    float3 lightDirectionWS = _LightDirection;
                #endif

                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif

                return positionCS;
            }

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = GetShadowPositionHClip(input);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                return 0;
            }

            ENDHLSL
        }
    }
}
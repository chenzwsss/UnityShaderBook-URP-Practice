Shader "URP Practice/Common/BumpedDiffuse"
{
    Properties
    {
        // 基础纹理
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [MainColor] _BaseColor("Color", Color) = (1, 1, 1, 1)
        // 法线贴图
        _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpMap_Scale("Bump Scale", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
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
                half4 _BaseColor;
                half4 _BaseMap_ST;
                half4 _BumpMap_ST;
                half _BumpMap_Scale;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION; // 顶点OS位置
                float3 normalOS : NORMAL; // 法线
                float4 tangentOS : TANGENT; // 切线
                float2 texcoord : TEXCOORD0; // 纹理坐标
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
                // 基础纹理和法线纹理的uv计算
                output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.uv.zw = TRANSFORM_TEX(input.texcoord, _BumpMap);

                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.tangentWS = TransformObjectToWorld(input.tangentOS.xyz);
                output.bitangentWS = cross(output.normalWS, output.tangentWS) * input.tangentOS.w;

                output.lightmapUV = input.lightmapUV.xy * unity_LightmapST.xy + unity_LightmapST.zw;

                return output;
            }

            half3 LightingBasedDiffuse(Light light, half3 normalWS, half3 albedo)
            {
                // 光源方向
                half3 lightDirectionWS = normalize(light.direction);
                // 计算漫反射
                half3 diffuse = light.color * albedo * saturate(dot(normalWS, lightDirectionWS));
                // 考虑光的强度和阴影
                return diffuse * light.distanceAttenuation * light.shadowAttenuation;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // 对法线纹理采样
                half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv.zw), _BumpMap_Scale);

                // 切线空间下的法线转换到世界空间
                // 切线空间x轴: 切线tangent, y轴: 副切线bitangent, z轴: 法线normal
                half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz);
                half3 normalWS = normalize(TransformTangentToWorld(normalTS, tangentToWorld));

                // 纹理采样
                half3 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv.xy).rgb * _BaseColor.rgb;

                // 计算环境环境光
                half3 ambient = SampleSH(normalWS) * albedo;

                half4 shadowMask = SAMPLE_SHADOWMASK(i.lightmapUV);

                // 获取阴影坐标
                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);

                // 计算主光源与阴影
                Light mainLight = GetMainLight(shadowCoord, input.positionWS, shadowMask);
                half3 diffuse = LightingBasedDiffuse(mainLight, normalWS, albedo);

                // 计算其他光源与阴影
                uint pixelLightsCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0; lightIndex < pixelLightsCount; ++lightIndex)
                {
                    Light light = GetAdditionalLight(lightIndex, input.positionWS, shadowMask);
                    diffuse += LightingBasedDiffuse(light, normalWS, albedo);
                }

                return half4(ambient + diffuse, 1.0);
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
}
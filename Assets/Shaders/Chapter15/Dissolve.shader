Shader "URP Practice/Chapter 15/Dissolve"
{
    Properties
    {
        // 控制消融成都, 0.0 时正常效果; 1.0时物体会完全消融
        _BurnAmount ("Burn Amount", Range(0.0, 1.0)) = 0.0
        // 控制模拟烧焦效果时的线宽, 值越大, 火焰边缘的蔓延范围越广
        _LineWidth ("Burn Line Width", Range(0.0, 0.2)) = 0.1
        // 基础纹理
        _MainTex ("Base (RGB)", 2D) = "white" {}
        // 法线纹理
        _Bump ("Normal Map", 2D) = "bump" {}
        // 火焰边缘的2种颜色
        _BurnFirstColor ("Burn First Color", Color) = (1, 0, 0, 1)
        _BurnSecondColor ("Burn Second Color", Color) = (1, 0, 0, 1)
        // 噪声纹理
        _BurnMap ("Burn Map", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_Bump);
        SAMPLER(sampler_Bump);
        TEXTURE2D(_BurnMap);
        SAMPLER(sampler_BurnMap);

        CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float4 _Bump_ST;
            float4 _BurnMap_ST;
            half4 _BurnFirstColor;
            half4 _BurnSecondColor;
            half _BurnAmount;
            half _LineWidth;
        CBUFFER_END

        ENDHLSL

        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            Cull Off

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
                float4 tangentOS : TANGENT;
                float2 texcoord : TEXCOORD0;
                float2 lightmapUV : TEXCOORD1;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 tangentWS : TEXCOORD2;
                float3 bitangentWS : TEXCOORD3;
                float2 uvMainTex : TEXCOORD4;
                float2 uvBumpMap : TEXCOORD5;
                float2 uvBurnMap : TEXCOORD6;
                float2 lightmapUV : TEXCOORD7;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.tangentWS = TransformObjectToWorld(input.tangentOS.xyz);
                output.bitangentWS = cross(output.normalWS, output.tangentWS) * input.tangentOS.w;

                output.uvMainTex = TRANSFORM_TEX(input.texcoord, _MainTex);
                output.uvBumpMap = TRANSFORM_TEX(input.texcoord, _Bump);
                output.uvBurnMap = TRANSFORM_TEX(input.texcoord, _BurnMap);

                OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // 采样噪声纹理
                half3 burn = SAMPLE_TEXTURE2D(_BurnMap, sampler_BurnMap, input.uvBurnMap).rgb;
                // 采样结果和控制消融程度的属性 _BurnAmount, 小于 0 的像素直接 discard
                clip(burn.r - _BurnAmount);

                // 采样法线纹理, 并转换到世界空间
                float3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_Bump, sampler_Bump, input.uvBumpMap));
                half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz);
                half3 normalWS = normalize(TransformTangentToWorld(normalTS, tangentToWorld));

                // 采样阴影贴图
                half4 shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV);
                // 获取阴影坐标
                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);

                // 主光源和主光源方向
                Light mainLight = GetMainLight(shadowCoord);
                half3 lightDirectionWS = normalize(mainLight.direction);

                // 采样基础纹理得到 albedo
                half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uvMainTex).rgb;

                // 环境光照
                half3 ambient = SampleSH(normalWS) * albedo;
                // 漫发射光照
                half3 diffuse = mainLight.color * albedo * saturate(dot(normalWS, lightDirectionWS));

                // 在宽度为 _LineWidth 的范围内模拟一个烧焦的颜色变化
                // 使用 smoothstep 计算混合系数 t, t=1 时该像素位于消融的边界处; t=0 时该像素为正常的模型颜色
                half t = 1 - smoothstep(0.0, _LineWidth, burn.r - _BurnAmount);
                // 使用 t 来混合两种火焰颜色 _BurnFirstColor 和 _BurnSecondColor
                half3 burnColor = lerp(_BurnFirstColor, _BurnSecondColor, t);
                // 使用 pow 函数对结果进行处理使效果更接近烧焦的痕迹
                burnColor = pow(burnColor, 5);

                // 计算正常光照结果
                half3 c = ambient + diffuse * mainLight.distanceAttenuation * mainLight.shadowAttenuation;
                // 用 t 来混合正常的光照颜色和烧焦颜色, step(0.0001, _BurnAmount) 是为了保证 _BurnAmount=0 时，不显示任何消融效果
                half3 finalColor = lerp(c, burnColor, t * step(0.0001, _BurnAmount));

                return half4(finalColor, 1.0);
            }

            ENDHLSL
        }

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
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uvBurnMap : TEXCOORD0;
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

                output.uvBurnMap = TRANSFORM_TEX(input.texcoord, _BurnMap);

                return output;
            }

            half4 frag(Varyings input) : SV_TARGET
            {
                half4 burn = SAMPLE_TEXTURE2D(_BurnMap, sampler_BurnMap, input.uvBurnMap);

                clip(burn.r - _BurnAmount);

                return 0;
            }

            ENDHLSL
        }
    }

    FallBack Off
}

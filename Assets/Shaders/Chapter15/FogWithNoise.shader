Shader "URP Practice/Chapter 15/FogWithNoise"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _FogDensity ("Fog Density", Float) = 1.0
        _FogColor ("Fog Color", Color) = (1, 1, 1, 1)
        _FogStart ("Fog Start", Float) = 1.0
        _FogEnd ("Fog End", Float) = 1.0
        _NoiseTex ("Noise Texture", 2D) = "white" {}
        _FogXSpeed ("Fog Horizontal Speed", Float) = 0.1
        _FogYSpeed ("Fog Vertical Speed", Float) = 0.1
        _NoiseAmount ("Noise Amount", Float) = 1
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_NoiseTex);
        SAMPLER(sampler_NoiseTex);

        CBUFFER_START(UnityPerMaterial)
            float4x4 _FrustumCornersRay;
            float4 _MainTex_TexelSize;
            half4 _FogColor;
            half _FogDensity;
            half _FogStart;
            half _FogEnd;
            half _FogXSpeed;
            half _FogYSpeed;
            half _NoiseAmount;
        CBUFFER_END

        struct Attributes
        {
            float4 positionOS : POSITION;
            float2 texcoord : TEXCOORD0;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 uv : TEXCOORD0;
            float2 uv_depth : TEXCOORD1;
            float4 interpolatedRay : TEXCOORD2;
        };

        Varyings vert(Attributes input)
        {
            Varyings output;
            output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

            output.uv = input.texcoord;
            output.uv_depth = input.texcoord;

            // 根据像素点的位置选择输出那个 interpolatedRay
            int index = 0;
            // 左下角 bottomLeft
            if (input.texcoord.x < 0.5 && input.texcoord.y < 0.5)
            {
                index = 0;
            }
            // 右下角 bottomRight
            else if (input.texcoord.x > 0.5 && input.texcoord.y < 0.5)
            {
                index = 1;
            }
            // 右上角 topRight
            else if (input.texcoord.x > 0.5 && input.texcoord.y > 0.5)
            {
                index = 2;
            }
            // 左上角 topLeft
            else
            {
                index = 3;
            }

            #if UNITY_UV_STARTS_AT_TOP
                if (_MainTex_TexelSize.y < 0)
                {
                    output.uv_depth.y = 1 - output.uv_depth.y;
                    index = 3 - index;
                }
            #endif

            // 输出，插值后传给片元着色器
            output.interpolatedRay = _FrustumCornersRay[index];

            return output;
        }

        half4 frag(Varyings input) : SV_Target
        {
            // 采样深度纹理
            float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv_depth).r;
            // 转换为视角空间下的线性深度
            float linearDepth = LinearEyeDepth(depth, _ZBufferParams);

            // 重建像素世界空间位置
            float3 positionWS = GetCameraPositionWS() + linearDepth * input.interpolatedRay.xyz;

            float2 speed = _Time.y * float2(_FogXSpeed, _FogYSpeed);
            float noise = (SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, input.uv + speed).r - 0.5) * _NoiseAmount;

            // 根据材质属性 _FogEnd 和 _FogStart 计算当前的像素高度 positionWS.y 对应的雾效系数 fogDensity,
            // 再和参数 _FogDensity 相乘后，利用 saturate 函数截取到 [O, 1]范围内， 作为最后的雾效系数
            float fogDensity = (_FogEnd - positionWS.y) / (_FogEnd - _FogStart);
            fogDensity = saturate(fogDensity * _FogDensity * (1 + noise));

            half4 finalColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
            // 插值计算最终颜色
            finalColor.rgb = lerp(finalColor.rgb, _FogColor.rgb, fogDensity);

            return finalColor;
        }

        ENDHLSL

        Pass
        {
            ZTest Always Cull Off ZWrite Off

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            ENDHLSL
        }
    }
    FallBack Off
}

Shader "URP Practice/Chapter 12/GaussianBlur"
{
    Properties
    {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _BlurSize ("Blur Size", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_TexelSize;
            float _BlurSize;
        CBUFFER_END

        struct Attributes
        {
            float4 positionOS : POSITION;
            float2 texcoord : TEXCOORD0;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 uv[5] : TEXCOORD0;
        };

        Varyings vertBlurVertical(Attributes input)
        {
            Varyings output;

            output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

            float2 uv = input.texcoord;

            output.uv[0] = uv;
            output.uv[1] = uv + float2(0.0, _MainTex_TexelSize.y * 1.0) * _BlurSize;
            output.uv[2] = uv - float2(0.0, _MainTex_TexelSize.y * 1.0) * _BlurSize;
            output.uv[3] = uv + float2(0.0, _MainTex_TexelSize.y * 2.0) * _BlurSize;
            output.uv[4] = uv - float2(0.0, _MainTex_TexelSize.y * 2.0) * _BlurSize;

            return output;
        }

        Varyings vertBlurHorizontal(Attributes input)
        {
            Varyings output;

            output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

            float2 uv = input.texcoord;

            output.uv[0] = uv;
            output.uv[1] = uv + float2(_MainTex_TexelSize.x * 1.0, 0.0) * _BlurSize;
            output.uv[2] = uv - float2(_MainTex_TexelSize.x * 1.0, 0.0) * _BlurSize;
            output.uv[3] = uv + float2(_MainTex_TexelSize.x * 2.0, 0.0) * _BlurSize;
            output.uv[4] = uv - float2(_MainTex_TexelSize.x * 2.0, 0.0) * _BlurSize;

            return output;
        }

        half4 fragBlur(Varyings input) : SV_Target
        {
            float weight[3] = {0.4026, 0.2442, 0.0545};

            half3 sum = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv[0]).rgb * weight[0];

            for (int it = 1; it < 3; ++it)
            {
                sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv[it * 2 - 1]).rgb * weight[it];
                sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv[it * 2]).rgb * weight[it];
            }

            return half4(sum, 1.0);
        }

        ENDHLSL

        ZTest Always Cull Off ZWrite Off

        Pass
        {
            NAME "GAUSSIAN_BLUR_VERTICAL"

            HLSLPROGRAM

            #pragma vertex vertBlurVertical
            #pragma fragment fragBlur

            ENDHLSL
        }

        Pass
        {
            NAME "GAUSSIAN_BLUR_HORIZONTAL"

            HLSLPROGRAM

            #pragma vertex vertBlurHorizontal
            #pragma fragment fragBlur

            ENDHLSL
        }
    }

    Fallback Off
}

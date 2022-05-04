Shader "URP Practice/Chapter 12/Bloom"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        // _BloomTexture ("Bloom (RGB)", 2D) = "black" {}
        _LuminanceThreshold ("Luminance Threshold", Float) = 0.5
        _BlurSize ("Blur Size", Float) = 1.0
    }
    SubShader
    {
        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_BloomTexture);
        SAMPLER(sampler_BloomTexture);

        CBUFFER_START(UnityPerMaterial)
            half4 _MainTex_TexelSize;
            half _LuminanceThreshold;
            half _BlurSize;
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
        };

        Varyings vertExtractBright(Attributes input)
        {
            Varyings output;

            output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

            output.uv = input.texcoord;

            return output;
        }

        half luminance(half4 color)
        {
            return  0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b; 
        }

        half4 fragExtractBright(Varyings input) : SV_Target
        {
            half4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
            half val = clamp(luminance(c) - _LuminanceThreshold, 0.0, 1.0);

            return c * val;
        }

        struct VaryingsBloom
        {
            float4 positionCS : SV_POSITION;
            float4 uv : TEXCOORD0;
        };

        VaryingsBloom vertBloom(Attributes input)
        {
            VaryingsBloom output;

            output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

            output.uv.xy = input.texcoord;
            output.uv.zw = input.texcoord;

            #if UNITY_UV_STARTS_AT_TOP
                if (_MainTex_TexelSize.y < 0.0)
                    output.uv.w = 1.0 - output.uv.w;
            #endif

            return output;
        }

        half4 fragBloom(VaryingsBloom input) : SV_Target
        {
            half4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv.xy);
            half bloom = SAMPLE_TEXTURE2D(_BloomTexture, sampler_BloomTexture, input.uv.zw);
            return c + bloom;
        }

        ENDHLSL

        ZTest Always Cull Off ZWrite Off

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vertExtractBright
            #pragma fragment fragExtractBright

            ENDHLSL
        }

        UsePass "URP Practice/Chapter 12/GaussianBlur/GAUSSIAN_BLUR_VERTICAL"

        UsePass "URP Practice/Chapter 12/GaussianBlur/GAUSSIAN_BLUR_HORIZONTAL"

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vertBloom
            #pragma fragment fragBloom

            ENDHLSL
        }
    }
    FallBack Off
}

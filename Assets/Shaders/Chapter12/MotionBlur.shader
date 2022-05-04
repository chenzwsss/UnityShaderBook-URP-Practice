Shader "URP Practice/Chapter 12/MotionBlur"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _BlurAmount ("Blur Amount", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipelien" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        CBUFFER_START(UnityPerMaterial)
            half _BlurAmount;
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

        Varyings vert(Attributes input)
        {
            Varyings output;

            output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
            output.uv = input.texcoord;

            return output;
        }

        half4 fragRGB(Varyings input) : SV_Target
        {
            return half4(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv).rgb, _BlurAmount);
        }

        half4 fragA(Varyings input) : SV_Target
        {
            return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
        }

        ENDHLSL

        ZTest Always Cull Off ZWrite Off

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ColorMask RGB

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragRGB
            ENDHLSL
        }

        Pass
        {
            Blend One Zero
            ColorMask A

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragA
            ENDHLSL
        }
    }
    FallBack Off
}

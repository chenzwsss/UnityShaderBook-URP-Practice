Shader "URP Practice/Chapter 13/EdgeDetectNormalsAndDepth"
{
    Properties
    {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _EdgeOnly ("Edge Only", Float) = 1.0
        _EdgeColor ("Edge Color", Color) = (0, 0, 0, 1)
        _BackgroundColor ("Background Color", Color) = (1, 1, 1, 1)
        _SampleDistance ("Sample Distance", Float) = 1.0
        _Sensitivity ("Sensitivity", Vector) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        CBUFFER_START(UnityPerMaterial)
            half4 _MainTex_TexelSize;
            half4 _EdgeColor;
            half4 _BackgroundColor;
            half _EdgeOnly;
            float _SampleDistance;
            half4 _Sensitivity;
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

        Varyings vert(Attributes input)
        {
            Varyings output;
            output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

            float2 uv = input.texcoord;
            output.uv[0] = uv;

            #if UNITY_UV_STARTS_AT_TOP
                if (_MainTex_TexelSize.y < 0)
                    uv.y = 1 - uv.y;
            #endif

            output.uv[1] = uv + _MainTex_TexelSize.xy * float2(1, 1) * _SampleDistance;
            output.uv[2] = uv + _MainTex_TexelSize.xy * float2(-1, -1) * _SampleDistance;
            output.uv[3] = uv + _MainTex_TexelSize.xy * float2(-1, 1) * _SampleDistance;
            output.uv[4] = uv + _MainTex_TexelSize.xy * float2(1, -1) * _SampleDistance;

            return output;
        }

        float CheckSame(half2 centerNormal, float centerDepth, half2 sampleNormal, float sampleDepth)
        {
            half2 diffNormal = abs(centerNormal - sampleNormal) * _Sensitivity.x;
            int isSameNormal = (diffNormal.x + diffNormal.y) < 0.1;

            float diffDepth = abs(centerDepth - sampleDepth) * _Sensitivity.y;
            int isSameDepth = diffDepth < 0.1 * centerDepth;

            return isSameNormal * isSameDepth ? 1.0 : 0.0;
        }

        half4 fragRobertsCrossDepthAndNormal(Varyings input) : SV_Target
        {
            half3 sampleNormal1 = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, input.uv[1]).xyz;
            float sampleDepth1 = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv[1]).r;
            half3 sampleNormal2 = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, input.uv[2]).xyz;
            float sampleDepth2 = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv[2]).r;
            half3 sampleNormal3 = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, input.uv[3]).xyz;
            float sampleDepth3 = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv[3]).r;
            half3 sampleNormal4 = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, input.uv[4]).xyz;
            float sampleDepth4 = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv[4]).r;

            float edge = 1.0;

            edge *= CheckSame(sampleNormal1.xy, sampleDepth1, sampleNormal2.xy, sampleDepth2);
            edge *= CheckSame(sampleNormal3.xy, sampleDepth3, sampleNormal4.xy, sampleDepth4);

            half4 withEdgeColor = lerp(_EdgeColor, SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv[0]), edge);
            half4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge);

            return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);
        }

        ENDHLSL

        Pass
        {
            ZTest Always Cull Off ZWrite Off

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment fragRobertsCrossDepthAndNormal;

            ENDHLSL
        }
    }
    FallBack Off
}

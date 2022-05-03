Shader "URP Practice/Chapter 11/ScrollingBackground"
{
    Properties
    {
        _BaseMap("Base Map", 2D) = "white" {}
        _DetailMap("2nd Map", 2D) = "White" {}
        _ScrollX("Base Map Scroll Speed", Float) = 1.0
        _Scroll2X("2nd Map Scroll Speed", Float) = 1.0
        _Multiplier("Layer Multiplier", Float) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_DetailMap);
            SAMPLER(sampler_DetailMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _DetailMap_ST;
                half _ScrollX;
                half _Scroll2X;
                half _Multiplier;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 uv : TEXCOORD0;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

                // frac(x) 返回 x 的小数部分, 返回的结果 [0, 1)
                // 利用 _Time.y 变量对纹理坐标进行偏移, 注意: 纹理的 Wrap Mode 需要设置成 Repeat 模式
                output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap) + frac(float2(_ScrollX, 0.0) * _Time.y);
                output.uv.zw = TRANSFORM_TEX(input.texcoord, _DetailMap) + frac(float2(_Scroll2X, 0.0) * _Time.y);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                half4 firstLayer = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv.xy);
                half4 secondLayer = SAMPLE_TEXTURE2D(_DetailMap, sampler_DetailMap, input.uv.zw);

                half4 finalColor = lerp(firstLayer, secondLayer, secondLayer.a);
                finalColor.rgb *= _Multiplier;

                return finalColor;
            }

            ENDHLSL
        }
    }
}

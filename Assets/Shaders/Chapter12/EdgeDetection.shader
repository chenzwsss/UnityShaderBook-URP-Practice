Shader "URP Practice/Chapter 12/EdgeDetection"
{
    Properties
    {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _EdgeOnly ("Edge Only", Float) = 1.0
        _EdgeColor ("Edge Color", Color) = (0, 0, 0, 1)
        _BackgroundColor ("Background Color", Color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }
        Pass
        {
            ZTest Always Cull Off ZWrite Off

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            CBUFFER_START(UnityPerMaterial)
                half4 _MainTex_TexelSize;
                half4 _EdgeColor;
                half4 _BackgroundColor;
                half _EdgeOnly;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                half2 uv[9] : TEXCOORD0;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

                half2 uv = input.texcoord;
                output.uv[0] = uv + _MainTex_TexelSize.xy * half2(-1, -1);
                output.uv[1] = uv + _MainTex_TexelSize.xy * half2(0, -1);
                output.uv[2] = uv + _MainTex_TexelSize.xy * half2(1, -1);
                output.uv[3] = uv + _MainTex_TexelSize.xy * half2(-1, 0);
                output.uv[4] = uv + _MainTex_TexelSize.xy * half2(0, 0);
                output.uv[5] = uv + _MainTex_TexelSize.xy * half2(1, 0);
                output.uv[6] = uv + _MainTex_TexelSize.xy * half2(-1, 1);
                output.uv[7] = uv + _MainTex_TexelSize.xy * half2(0, 1);
                output.uv[8] = uv + _MainTex_TexelSize.xy * half2(1, 1);

                return output;
            }

            half luminance(half4 color)
            {
                return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
            }

            half Sobel(Varyings input)
            {
                const half Gx[9] = {-1,  0,  1,
                                        -2,  0,  2,
                                        -1,  0,  1};
                const half Gy[9] = {-1, -2, -1,
                                        0,  0,  0,
                                        1,  2,  1};

                half texColor;
                half edgeX = 0;
                half edgeY = 0;
                for (int it = 0; it < 9; ++it)
                {
                    texColor = luminance(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv[it]));
                    edgeX += texColor * Gx[it];
                    edgeY += texColor * Gy[it];
                }

                half edge = 1 - abs(edgeX) - abs(edgeY);

                return edge;
            }

            half4 frag(Varyings input) : SV_Target
            {
                half edge = Sobel(input);

                half4 withEdgeColor = lerp(_EdgeColor, SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv[4]), edge);
                half4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge);

                return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);
            }

            ENDHLSL
        }
    }
}

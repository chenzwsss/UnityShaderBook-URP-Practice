Shader "URP Practice/Chapter 10/Mirror"
{
    Properties
    {
        _BaseMap("Base Map", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaqua" "RenderPipeline"="UniversalPipeline" }
        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

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

                // 因为镜子里显示的图像是左右相反的, 所以翻转纹理坐标的x分量
                output.uv.x = 1.0 - output.uv.x;

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                return SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
            }

            ENDHLSL
        }
    }
}

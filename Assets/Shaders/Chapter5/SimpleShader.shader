Shader "URP Practice/Chapter 5/Simple Shader"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }

        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
            CBUFFER_END
        ENDHLSL

        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                // vertex position
                float4 positionOS : POSITION;
                // normal
                float3 normal : NORMAL;
            };

            struct Varyings
            {
                // vertex position in clip space
                float4 positionHCS : SV_POSITION;
                half3 color : COLOR0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.color = IN.normal * 0.5 + half3(0.5, 0.5, 0.5);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 c = IN.color;
                c *= _BaseColor.rgb;
                return half4(c, 1.0);
            }

            ENDHLSL
        }
    }
}
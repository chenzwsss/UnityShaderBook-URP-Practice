Shader "URP Practice/Chapter 8/BlendOperations1"
{
    Properties
    {
        _Color("Color Tint", Color) = (1, 1, 1, 1)
        _BaseMap("Base Map", 2D) = "white" {}
        _AlphaScale("Alpha Scale", Range(0, 1)) = 1
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderPipeline"="UniversalRenderPipeline" }
        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            ZWrite Off

            // Normal 正常(透明度混合)
            // Blend SrcAlpha OneMinusSrcAlpha

            // Soft Additive 柔和相加
            // Blend OneMinusDstColor One

            // // Multiply 正片叠底(相乘)
            // Blend DstColor Zero

            // // 2x Multiply 2倍相乘
            // Blend DstColor SrcColor

            // // Darken 变暗
            // BlendOp Min
            // Blend One One    // When using Min operation, these factors are ignored

            // //  Lighten 变亮
            // BlendOp Max
            // Blend One One    // When using Max operation, these factors are ignored

            // Screen 滤色
            // Blend OneMinusDstColor One
            // // Or 等同于
            // Blend One OneMinusSrcColor

            // // Linear Dodge 线性减淡
            Blend One One

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                half4 _BaseMap_ST;
                half _AlphaScale;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD1;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 textureColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                return half4(textureColor.rgb * _Color.rgb, textureColor.a * _AlphaScale);
            }

            ENDHLSL
        }
    }
}
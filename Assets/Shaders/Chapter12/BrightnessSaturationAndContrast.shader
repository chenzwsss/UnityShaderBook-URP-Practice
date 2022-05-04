Shader "URP Practice/Chapter 12/BrightnessSaturationAndContrast"
{
    Properties
    {
        // 基础纹理
        _MainTex ("Base Map (RGB)", 2D) = "white" {}
        //亮度
        _Brightness ("Brightness", Float) = 1
        //饱和度
        _Saturation ("Saturation", Float) = 1
        // 对比度
        _Contrast ("Contrast", Float) = 1
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPepeline" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half _Brightness;
        half _Saturation;
        half _Contrast;
        CBUFFER_END

        ENDHLSL

        Pass
        {
            // 开启深度测试 关闭剔除 关闭深度写入
            ZTest Always Cull Off ZWrite Off

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

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

                output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // 纹理采样
                half4 renderTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);

                // 调整亮度 = 原颜色 * 亮度值
                half3 finalColor = renderTex.rgb * _Brightness;

                // 调整饱和度
                // 获取亮度值
                half luminance = 0.2125 * renderTex.r + 0.7154 * renderTex.g + 0.0721 * renderTex.b;
                half3 luminanceColor = half3(luminance, luminance, luminance);
                // 插值亮度值和原值
                finalColor = lerp(luminanceColor, finalColor, _Saturation);

                // 调整对比度
                // 对比度为0的颜色
                half3 avgColor = half3(0.5, 0.5, 0.5);
                finalColor = lerp(avgColor, finalColor, _Contrast);

                return half4(finalColor, renderTex.a);
            }

            ENDHLSL
        }
    }

    Fallback Off
}

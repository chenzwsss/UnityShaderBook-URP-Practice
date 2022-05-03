Shader "URP Practice/Chapter 11/ImageSequenceAnimation"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _BaseMap("Base Map", 2D) = "white" {}
        _HorizontalAmount("Horizontal Amount", Float) = 4
        _VerticalAmount("Vertical Amount", Float) = 4
        _Speed("Speed", Range(1.0, 100.0)) = 30.0
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "RenderPipeline"="UniversalPipeline" }
        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _BaseMap_ST;
                half _HorizontalAmount;
                half _VerticalAmount;
                half _Speed;
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
                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // _Time.y 是该场景加载后所经过的时间
                // _Time.y 和速度属性 _Speed 相乘得到模拟的时间, 并用 floor 函数向下取整
                float time = floor(_Time.y * _Speed);
                // 用 time 除以 _HorizontalAmount 的结果值的商来作为当前对应的行索引
                float row = floor(time / _HorizontalAmount);
                // 用 time 除以 _HorizontalAmount 的结果值的余数作为列索引
                float column = time - row * _HorizontalAmount;

                // 把原纹理坐标 input.uv 按行数和列数进行等分, 得到每个子图像的纹理坐标范围
                float2 uv = float2(input.uv.x / _HorizontalAmount, input.uv.y / _VerticalAmount);
                // 使用当前的行、列数进行偏移, 得到当前子图像的纹理坐标
                // 在 Unity 中纹理坐标竖直方向的顺序是从下到上增大, 这和序列帧纹理中的顺序是相反的, 所以竖直方向的偏移是减法
                uv.x += (column / _HorizontalAmount);
                uv.y -= (row / _VerticalAmount);
                // 上面的代码可以简化为下面的代码
                // half2 uv = input.uv + half2(column, -row);
                // uv.x /= _HorizontalAmount;
                // uv.y /= _VerticalAmount;

                half4 c = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
                c.rgb *= _BaseColor.rgb;

                return c;
            }

            ENDHLSL
        }
    }
}

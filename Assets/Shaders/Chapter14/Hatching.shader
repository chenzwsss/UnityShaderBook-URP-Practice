Shader "URP Practice/Chapter 14/Hatching"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        // 纹理的平铺系数, 越大，素描线条越密
        _TileFactor ("Tile Factor", Float) = 1
        _Outline ("Outline", Range(0.0, 1.0)) = 0.1
        // _Hatch0 到 _Hatch5 是使用的6张素描纹理, 它们的线条密度依次增大
        _Hatch0 ("Hatch 0", 2D) = "white" {}
        _Hatch1 ("Hatch 1", 2D) = "white" {}
        _Hatch2 ("Hatch 2", 2D) = "white" {}
        _Hatch3 ("Hatch 3", 2D) = "white" {}
        _Hatch4 ("Hatch 4", 2D) = "white" {}
        _Hatch5 ("Hatch 5", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        UsePass "URP Practice/Chapter 14/ToonShading/OUTLINE"

        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_Hatch0);
            SAMPLER(sampler_Hatch0);
            TEXTURE2D(_Hatch1);
            SAMPLER(sampler_Hatch1);
            TEXTURE2D(_Hatch2);
            SAMPLER(sampler_Hatch2);
            TEXTURE2D(_Hatch3);
            SAMPLER(sampler_Hatch3);
            TEXTURE2D(_Hatch4);
            SAMPLER(sampler_Hatch4);
            TEXTURE2D(_Hatch5);
            SAMPLER(sampler_Hatch5);

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                float _TileFactor;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                half3 hatchWeights0 : TEXCOORD1;
                half3 hatchWeights1 : TEXCOORD2;
                float3 positionWS : TEXCOORD3;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

                output.uv = input.texcoord.xy * _TileFactor;

                Light mainLight = GetMainLight();

                // 计算漫反射系数 diff
                half3 lightDirectionWS = normalize(mainLight.direction);
                half3 normalWS = normalize(TransformObjectToWorldNormal(input.normalOS));
                half diff = max(0.0, dot(normalWS, lightDirectionWS));

                // 初始化6张纹理的权重, 分为2个 half3 存储
                output.hatchWeights0 = half3(0, 0, 0);
                output.hatchWeights1 = half3(0, 0, 0);

                // 把 diff 缩放到 [0, 7] 的范围
                float hatchFactor = diff * 7.0;

                // 通过判断 hatchFactor 所处的子区间来计算对应的纹理混合权重
                if (hatchFactor > 6.0)
                {
                    // Pure white, do nothing
                }
                else if (hatchFactor > 5.0)
                {
                    output.hatchWeights0.x = hatchFactor - 5.0;
                }
                else if (hatchFactor > 4.0)
                {
                    output.hatchWeights0.x = hatchFactor - 4.0;
                    output.hatchWeights0.y = 1.0 - output.hatchWeights0.x;
                } else if (hatchFactor > 3.0)
                {
                    output.hatchWeights0.y = hatchFactor - 3.0;
                    output.hatchWeights0.z = 1.0 - output.hatchWeights0.y;
                }
                else if (hatchFactor > 2.0)
                {
                    output.hatchWeights0.z = hatchFactor - 2.0;
                    output.hatchWeights1.x = 1.0 - output.hatchWeights0.z;
                }
                else if (hatchFactor > 1.0)
                {
                    output.hatchWeights1.x = hatchFactor - 1.0;
                    output.hatchWeights1.y = 1.0 - output.hatchWeights1.x;
                }
                else
                {
                    output.hatchWeights1.y = hatchFactor;
                    output.hatchWeights1.z = 1.0 - output.hatchWeights1.y;
                }

                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // 对6张纹理分别采样
                half4 hatchTex0 = SAMPLE_TEXTURE2D(_Hatch0, sampler_Hatch0, input.uv) * input.hatchWeights0.x;
                half4 hatchTex1 = SAMPLE_TEXTURE2D(_Hatch1, sampler_Hatch1, input.uv) * input.hatchWeights0.y;
                half4 hatchTex2 = SAMPLE_TEXTURE2D(_Hatch2, sampler_Hatch2, input.uv) * input.hatchWeights0.z;
                half4 hatchTex3 = SAMPLE_TEXTURE2D(_Hatch3, sampler_Hatch3, input.uv) * input.hatchWeights1.x;
                half4 hatchTex4 = SAMPLE_TEXTURE2D(_Hatch4, sampler_Hatch4, input.uv) * input.hatchWeights1.y;
                half4 hatchTex5 = SAMPLE_TEXTURE2D(_Hatch5, sampler_Hatch5, input.uv) * input.hatchWeights1.z;

                // 通过从 1 中减去所有 6 张纹理的权重来得到纯白在渲染中的贡献度
                // 这是因为素描中往往有留白的部分，因此我们希望在最后的渲染中光照最亮的部分是纯白色的
                half4 whiteColor = half4(1, 1, 1, 1) * (1 - input.hatchWeights0.x - input.hatchWeights0.y - input.hatchWeights0.z - 
                            input.hatchWeights1.x - input.hatchWeights1.y - input.hatchWeights1.z);

                // 混合各个颜色值
                half4 hatchColor = hatchTex0 + hatchTex1 + hatchTex2 + hatchTex3 + hatchTex4 + hatchTex5 + whiteColor;

                Light mainLight = GetMainLight();
                return half4(hatchColor.rgb * _Color.rgb * mainLight.distanceAttenuation, 1.0);
            }

            ENDHLSL
        }
    }
    FallBack Off
}
 
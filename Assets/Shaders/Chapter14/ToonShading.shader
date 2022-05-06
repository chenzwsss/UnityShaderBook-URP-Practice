Shader "URP Practice/Chapter 14/ToonShading"
{
    Properties
    {
        _Color ("Color", Color) = (1, 1, 1, 1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        // 控制漫反射色调的渐变纹理
        _Ramp ("Ramp Texture", 2D) = "white" {}
        // 轮廓线宽度
        _Outline ("Outline", Range(0.0, 1.0)) = 0.1
        // 轮廓线颜色
        _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
        // 高光反射颜色
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        // 控制高光反射时使用的阈值
        _SpecularScale ("Specular Scale", Range(0.0, 0.1)) = 0.01
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        // 第一个 Pass, 使用轮廓线颜色渲染整个背面的面片, 并在视角空间下把模型顶点沿着法线方向向外扩张一段距离, 以此来让背部轮廓线可见
        Pass
        {
            NAME "OUTLINE"

            // 先剔除正面的三角形面片, 只渲染背面
            Cull Front

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _OutlineColor;
                float _Outline;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normal : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                // 把顶点和法线变化到视角空间下
                float4 pos = float4(TransformWorldToView(TransformObjectToWorld(input.positionOS.xyz)), 1.0);
                float3 normal = mul((float3x3) UNITY_MATRIX_I_V * UNITY_MATRIX_I_M, input.normal);
                // 设置法线的 z 分量为 -0.5,
                // 如果直接使用顶点法线进行扩展, 对于一些内凹的模型, 就可能发生背面面片遮挡正面面片的情况. 为了尽可能防止出现这样的情况,
                // 在扩张背面顶点之前，我们首先对顶点法线的 z 分量进行处理，使它们等于一个定值, 然后把法线归一化后再对顶点进行扩张
                // 这样的好处在于, 扩展后的背面更加扁平化, 从而降低了遮挡正面面片的可能性
                normal.z = -0.5;
                // 扩张顶点坐标
                pos = pos + float4(normalize(normal), 0.0) * _Outline;
                // 转换到裁剪空间
                output.positionCS = TransformWViewToHClip(pos.xyz);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // 用轮廓线颜色渲染整个背面
                return half4(_OutlineColor.rgb, 1);
            }

            ENDHLSL
        }

        // 第二个 Pass, 渲染正面的面片, 计算光照
        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            // 剔除背面的三角形面片
            Cull Back

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_Ramp);
            SAMPLER(sampler_Ramp);

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                half4 _MainTex_ST;
                half4 _Specular;
                half _SpecularScale;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);
                output.normalWS = TransformObjectToWorldNormal(input.normal);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                half3 normalWS = normalize(input.normalWS);

                Light mainLight = GetMainLight();

                half3 lightDirectionWS = normalize(mainLight.direction);
                half3 viewDirectionWS = GetWorldSpaceViewDir(input.positionWS.xyz);
                half3 halfDirWS = normalize(lightDirectionWS + viewDirectionWS);

                half4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                half3 albedo = c.rgb * _Color.rgb;

                half3 ambient = SampleSH(normalWS) * albedo;

                // 计算半兰伯特漫反射系数
                half diff = dot(normalWS, lightDirectionWS);
                diff = (diff * 0.5 + 0.5) * mainLight.distanceAttenuation;

                // 使用漫反射系数对渐变纹理 _Ramp 采样并计算漫反射光照
                half3 diffuse = mainLight.color * albedo * SAMPLE_TEXTURE2D(_Ramp, sampler_Ramp, float2(diff, diff)).rgb;

                // 高光反射
                // fwidth(x) = abs(ddx(x)) + abs(ddy(x))
                // 对于 函数fwidth 的理解可以看这篇知乎: https://www.zhihu.com/question/329521044/answer/1467082644

                // 计算高光项
                half spec = dot(normalWS, halfDirWS);
                // 计算该像素高光与相邻两个像素高光的差值, 对高光区域的边界进行抗锯齿处理
                half w = fwidth(spec) * 2.0;
                // 得到从 0 到 1 平滑变化的 spec 值
                half smoothSpec = lerp(0, 1, smoothstep(-w, w, spec + _SpecularScale - 1));
                // 计算高光, 最后的 step(0.0001, _SpecularScale) 是为了在 _SpecularScale 为 0 时, 完全消除高光反射光照
                half3 specular = _Specular.rgb * smoothSpec * step(0.0001, _SpecularScale);

                return half4(ambient + diffuse + specular, 1.0);
            }

            ENDHLSL
        }
    }
    FallBack Off
}

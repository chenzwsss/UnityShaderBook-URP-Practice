Shader "URP Practice/Chapter 10/Reflection"
{
    Properties
    {
        // 基础颜色
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        // 反射颜色
        _ReflectColor("Reflection Color", Color) = (1, 1, 1, 1)
        // 漫反射/反射 插值控制
        _ReflectAmount("Reflect Amount", Range(0.0, 1.0)) = 1.0
        // 环境立方体贴图
        _Cubemap("Reflection Cubemap", Cube) = "_Skybox" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" }
        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            samplerCUBE _Cubemap;
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _ReflectColor;
                half _ReflectAmount;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 reflectionWS : TEXCOORD2;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

                output.normalWS = TransformObjectToWorldNormal(input.normalOS);

                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);

                float3 viewDirectionWS = normalize(GetWorldSpaceViewDir(output.positionWS));
                // 视线方向的反射方向
                output.reflectionWS = reflect(-viewDirectionWS, normalize(output.normalWS));

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                half3 normalWS = normalize(input.normalWS);

                half3 ambient = SampleSH(normalWS) * _BaseColor.rgb;

                Light mainLight = GetMainLight();
                half3 lightDirectionWS = GetWorldSpaceViewDir(input.positionWS);

                half3 diffuse = mainLight.color * _BaseColor.rgb * saturate(dot(normalWS, lightDirectionWS));
                // 反射方向去cubemap上采样
                half3 reflection = texCUBE(_Cubemap, normalize(input.reflectionWS)).rgb * _ReflectColor.rgb;
                // 在漫反射和反射之间根据 _ReflectAmout 进行线性插值, _ReflectAmout=0.0=diffuse, _ReflectAmout=1.0=reflection,
                // _ReflectAmout 在0.0和1.0之间则为 (1.0 - _ReflectAmout) * diffuse + _ReflectAmouts * reflectoion
                half3 color = ambient + lerp(diffuse, reflection, _ReflectAmount);

                return half4(color, 1.0);
            }

            ENDHLSL
        }
    }
}
Shader "URP Practice/Chapter 10/SchlickFresnelReflection"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _FresnelScale("Fresnel Scale", Range(0.0, 1.0)) = 0.5
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
                half _FresnelScale;
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
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);

                float3 viewDirectionWS = GetWorldSpaceViewDir(output.positionWS);
                // 计算反射方向
                output.reflectionWS = reflect(-normalize(viewDirectionWS), normalize(output.normalWS));

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                half3 normalWS = normalize(input.normalWS);
                half3 viewDirectionWS = normalize(GetWorldSpaceViewDir(input.positionWS));

                Light mainLight = GetMainLight();

                half3 lightDirectionWS = normalize(mainLight.direction);
                // 环境光
                half3 ambient = SampleSH(normalWS) * _BaseColor.rgb;
                // 计算 Schlick-Fresnel
                half fresnel = _FresnelScale + (1.0 - _FresnelScale) * pow(1.0 - dot(viewDirectionWS, normalWS), 5);
                // 漫反射
                half3 diffuse = mainLight.color * _BaseColor.rgb * saturate(dot(normalWS, lightDirectionWS));
                // 反射采样
                half3 reflection = texCUBE(_Cubemap, normalize(input.reflectionWS)).rgb;

                half3 color = ambient + lerp(diffuse, reflection, saturate(fresnel)) * mainLight.distanceAttenuation;

                return half4(color, 1.0);
            }

            ENDHLSL
        }
    }
}

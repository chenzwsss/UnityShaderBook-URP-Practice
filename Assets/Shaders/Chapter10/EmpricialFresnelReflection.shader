Shader "URP Practice/Chapter 10/EmpricialFresnelReflection"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _FresnelBias("Fresnel Bias", Range(0.0, 1.0)) = 1.0
        _FresnelScale("Fresnel Scale", Range(0.0, 1.0)) = 1.0
        _FresnelPower("Fresnel Power", Range(0.0, 5.0)) = 5.0
        _Cubemap("Reflection Cubemap", Cube) = "_Skybox" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
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
                half _FresnelBias;
                half _FresnelScale;
                half _FresnelPower;
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
                float3 viewDirectionWS : TEXCOORD3;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);

                output.viewDirectionWS = GetWorldSpaceViewDir(output.positionWS);

                output.reflectionWS = reflect(-normalize(output.viewDirectionWS), normalize(output.normalWS));

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                half3 normalWS = normalize(input.normalWS);
                half3 viewDirectionWS = normalize(input.viewDirectionWS);

                half3 ambient = SampleSH(normalWS).rgb * _BaseColor.rgb;

                Light mainLight = GetMainLight();

                half3 lightDirectionWS = normalize(mainLight.direction);

                half3 diffuse = mainLight.color * _BaseColor.rgb * saturate(dot(normalWS, lightDirectionWS));

                half3 reflection = texCUBE(_Cubemap, normalize(input.reflectionWS)).rgb;

                // 计算 Empricial-Fresnel
                half fresnel = max(0.0, min(1.0, _FresnelBias + _FresnelScale * pow(1.0 - dot(viewDirectionWS, normalWS), _FresnelPower)));

                half3 color = ambient + lerp(diffuse, reflection, fresnel) * mainLight.distanceAttenuation;

                return half4(color, 1.0);
            }

            ENDHLSL
        }
    }
}

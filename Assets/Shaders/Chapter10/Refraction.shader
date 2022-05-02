Shader "URP Practice/Chapter 10/Refraction"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _RefractColor("Refraction Color", Color) = (1, 1, 1, 1)
        _RefracAmount("Refraction Amount", Range(0.0, 1.0)) = 1.0
        _RefractRatio("Refraction Ratio", Range(0.1, 1.0)) = 0.5
        _Cubemap("Refraction Cubemap", Cube) = "_Skybox" {}
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
                half4 _RefractColor;
                half _RefracAmount;
                half _RefractRatio;
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
                float3 refractionDirWS : TEXCOORD2;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);

                float3 viewDirectionWS = normalize(GetWorldSpaceViewDir(output.positionWS));
                output.refractionDirWS = refract(-viewDirectionWS, normalize(output.normalWS), _RefractRatio);

                return output;
            }

            half3 LightingBased(Light light, half3 normalWS)
            {
                half3 lightDirectionWS = normalize(light.direction);

                half3 diffuse = light.color * _BaseColor.rgb * saturate(dot(normalWS, lightDirectionWS));

                return diffuse;
            }

            half4 frag(Varyings input) : SV_Target
            {
                half3 normalWS = normalize(input.normalWS);
                // ambient
                half3 ambient = SampleSH(normalWS) * _BaseColor.rgb;
                // calculate main light
                Light mainLight = GetMainLight();
                // diffuse
                half3 diffuse = LightingBased(mainLight, normalWS);
                // sample cubemap calculate refraction
                half3 refraction = texCUBE(_Cubemap, normalize(input.refractionDirWS)).rgb * _RefractColor.rgb;

                half3 color = ambient + lerp(diffuse, refraction, _RefracAmount) * mainLight.distanceAttenuation;

                return half4(color, 1.0);
            }

            ENDHLSL
        }
    }
}
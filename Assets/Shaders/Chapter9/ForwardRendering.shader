Shader "URP Practice/Chapter 9/ForwardRendering"
{
    Properties
    {
        _Diffuse("Diffuse", Color) = (1, 1, 1, 1)
        _Specular("Specular", Color) = (1, 1, 1, 1)
        _Gloss("Gloss", Range(8, 256)) = 20
        [Toggle(_AdditionalLights)] _AddLights ("AddLights", Float) = 1
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalRenderPipeline" }

        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _Diffuse;
                half4 _Specular;
                half _Gloss;
            CBUFFER_END
        ENDHLSL

        Pass
        {
            Tags { "LightMode"="UniversalForward" }
            
            HLSLPROGRAM

            #pragma shader_feature _AdditionalLights

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normal : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normal);

                return OUT;
            }

            half3 LightingBase(Light light, half3 normalWS, half3 viewDirectionWS)
            {
                half3 lightDirectionWS = normalize(light.direction);

                half3 diffuse = light.color * _Diffuse.rgb * max(dot(normalWS, lightDirectionWS), 0.0);

                half3 halfDir = normalize(lightDirectionWS + viewDirectionWS);
                half3 specular = light.color * _Specular.rgb * pow(max(dot(normalWS, halfDir), 0.0), _Gloss);

                return (diffuse + specular) * light.distanceAttenuation;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // normal in WS
                half3 normalWS = normalize(IN.normalWS);
                half3 viewDirectionWS = normalize(GetWorldSpaceViewDir(IN.positionWS));

                // ambient
                half3 ambient = SampleSH(normalWS);

                // main light
                Light mainLight = GetMainLight();
                half3 baseLighting = LightingBase(mainLight, normalWS, viewDirectionWS);

                // additional lights
                #ifdef _AdditionalLights
                    uint pixelLightCount = GetAdditionalLightsCount();
                    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
                    {
                        Light light = GetAdditionalLight(lightIndex, IN.positionWS);
                        baseLighting += LightingBase(light, normalWS, viewDirectionWS);
                    }
                #endif

                return half4(ambient + baseLighting, 1.0);
            }

            ENDHLSL
        }
    }
}
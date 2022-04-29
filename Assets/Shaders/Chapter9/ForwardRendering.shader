Shader "URP Practice/Chapter 9/ForwardRendering"
{
    Properties
    {
        _Color("Color Tint", Color) = (1, 1, 1, 1)
        _Diffuse("Diffuse", Color) = (1, 1, 1, 1)
        _Specular("Specular", Color) = (1, 1, 1, 1)
        _Gloss("Gloss", Range(8, 256)) = 20
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalRenderPipeline" }
        Pass
        {
            Tags { "LightMode"="UniversalForward" }
            
            HLSLPROGRAM

            // #pragma shader_feature _AdditionalLights

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                half4 _Diffuse;
                half4 _Specular;
                half _Gloss;
            CBUFFER_END

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

            half4 frag(Varyings IN) : SV_Target
            {
                // normal in WS
                half3 normalWS = normalize(IN.normalWS);

                // main light
                Light mainLight = GetMainLight();
                half3 lightDirectionWS = normalize(mainLight.direction);
                // ambient
                half3 ambient = SampleSH(normalWS) * _Color.rgb;
                // main light diffuse
                half3 diffuse = mainLight.color * _Diffuse.rgb * max(dot(normalWS, lightDirectionWS), 0.0) * mainLight.distanceAttenuation;
                // main light specular
                half3 viewDirectionWS = normalize(GetWorldSpaceViewDir(IN.positionWS));
                half3 halfDir = normalize(viewDirectionWS + lightDirectionWS);
                half3 specular = mainLight.color * _Specular.rgb * pow(max(dot(normalWS, halfDir), 0.0), _Gloss) * mainLight.distanceAttenuation;

                // other lights
                uint pixelLightCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
                {
                    Light light = GetAdditionalLight(lightIndex, IN.positionWS);

                    lightDirectionWS = normalize(light.direction);

                    diffuse += light.color * _Diffuse.rgb * max(dot(normalWS, lightDirectionWS), 0.0) * light.distanceAttenuation;

                    halfDir = normalize(viewDirectionWS + lightDirectionWS);
                    specular += light.color * _Specular.rgb * pow(max(dot(normalWS, halfDir), 0.0), _Gloss) * light.distanceAttenuation;
                }

                return half4(ambient + diffuse + specular, 1.0);
            }

            ENDHLSL
        }
    }
}
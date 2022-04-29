Shader "URP Practice/Chapter 6/BlinnPhong"
{
    Properties
    {
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
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
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
                float3 normalWS : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

                OUT.normalWS = TransformObjectToWorldNormal(IN.normal);

                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 normalWS = normalize(IN.normalWS);
                half3 viewDirectionWS = normalize(GetWorldSpaceViewDir(IN.positionWS));

                Light mainLight = GetMainLight();
                half3 lightDirectionWS = normalize(mainLight.direction);

                half3 ambient = SampleSH(normalWS);

                half3 diffuse = mainLight.color * _Diffuse.rgb * max(dot(normalWS, lightDirectionWS), 0.0);

                // blinn-phong
                half3 halfDir = normalize(viewDirectionWS + lightDirectionWS);
                half3 specular = mainLight.color * _Specular.rgb * pow(max(dot(normalWS, halfDir), 0.0), _Gloss);

                return half4(ambient + diffuse + specular, 1.0);
            }

            ENDHLSL
        }
    }
}
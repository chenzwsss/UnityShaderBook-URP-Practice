Shader "URP Practice/Chapter 6/Specular Vertex-Level"
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
                half3 color : COLOR0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

                half3 normalWS = normalize(TransformObjectToWorldNormal(IN.normal));

                // ambient
                half3 ambient = SampleSH(normalWS);

                Light mainLight = GetMainLight();
                half3 lightDirectionWS = normalize(mainLight.direction);

                half3 diffuse = mainLight.color * _Diffuse.rgb * max(dot(normalWS, lightDirectionWS), 0.0);

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                half3 viewDirectionWS = normalize(GetWorldSpaceViewDir(positionWS));

                // phong
                half3 reflectDir = normalize(reflect(-lightDirectionWS, normalWS));
                half3 specular = mainLight.color * _Specular.rgb * pow(max(dot(reflectDir, viewDirectionWS), 0.0), _Gloss);

                OUT.color = ambient + diffuse + specular;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                return half4(IN.color, 1.0);
            }

            ENDHLSL
        }
    }
}
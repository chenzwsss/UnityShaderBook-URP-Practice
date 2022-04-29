Shader "URP Practice/Chapter 6/HalfLambert"
{
    Properties
    {
        _Diffuse("Diffuse", Color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalRenderPipeline" }

        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _Diffuse;
            CBUFFER_END
        ENDHLSL

        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM

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
                float3 normalWS : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

                OUT.normalWS = TransformObjectToWorldNormal(IN.normal);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 normalWS = normalize(IN.normalWS);

                Light mainLight = GetMainLight();
                half3 lightDirectionWS = normalize(mainLight.direction);

                half3 ambient = SampleSH(normalWS);

                half halfLambert = dot(normalWS, lightDirectionWS) * 0.5 + 0.5;

                half3 diffuse = mainLight.color * _Diffuse.rgb * halfLambert;

                return half4(ambient + diffuse, 1.0);
            }

            ENDHLSL
        }
    }
}

Shader "URP Practice/Chapter 6/Diffuse Vertex-Level"
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
                half3 color : COLOR0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

                half3 normalWS = normalize(TransformObjectToWorldNormal(IN.normal));

                half3 ambient = SampleSH(normalWS);

                Light mainLight = GetMainLight();
                half3 lightDirectionWS = normalize(mainLight.direction);
                half3 diffuse = mainLight.color * _Diffuse.rgb * max(dot(normalWS, lightDirectionWS), 0.0);

                OUT.color = ambient + diffuse;
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
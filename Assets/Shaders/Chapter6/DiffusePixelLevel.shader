Shader "URP Practice/Chapter 6/Diffuse Pixel-Level"
{
    Properties
    {
        _Diffuse("Diffuse", Color) = (1, 1, 1, 1)
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

                // Directional Light
                Light mainLight = GetMainLight();
                half3 lightDirectionWS = normalize(mainLight.direction);

                // ambient
                half3 ambient = SampleSH(normalWS);

                half3 diffuse = mainLight.color * _Diffuse.rgb * max(dot(normalWS, lightDirectionWS), 0.0);

                return half4(ambient + diffuse, 1.0);
            }

            ENDHLSL
        }
    }
}
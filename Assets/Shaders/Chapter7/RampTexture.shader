Shader "URP Practice/Chapter 7/RampTexture"
{
    Properties
    {
        _Color("Color Tint", Color) = (1, 1, 1, 1)
        _RampTex("Ramp Tex", 2D) = "white" {}
        _Specular("Specular", Color) = (1, 1, 1, 1)
        _Gloss("Gloss", Range(8.0, 256)) = 20
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

            TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                half4 _RampTex_ST;
                half4 _Specular;
                half _Gloss;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

                OUT.normalWS = TransformObjectToWorldNormal(IN.normal);

                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);

                OUT.uv = TRANSFORM_TEX(IN.uv, _RampTex);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // normalize normal in WS
                half3 normalWS = normalize(IN.normalWS);
                // get main light
                Light mainLight = GetMainLight();
                // light direction in WS
                half3 lightDirectionWS = normalize(mainLight.direction);
                // view direction in WS
                half3 viewDirectionWS = normalize(GetWorldSpaceViewDir(IN.positionWS));

                // sample texture
                half3 rampAlbedo = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, IN.uv).rgb * _Color.rgb;

                // ambient
                half3 ambient = SampleSH(normalWS);

                half halfLambert = dot(normalWS, lightDirectionWS) * 0.5 + 0.5;
                half3 diffuseColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, half2(halfLambert, halfLambert)).rgb;

                // diffuse
                half3 diffuse = mainLight.color * diffuseColor;

                // specular
                half3 halfDir = normalize(lightDirectionWS + viewDirectionWS);
                half3 specular = mainLight.color * _Specular.rgb * pow(max(dot(normalWS, halfDir), 0.0), _Gloss);

                return half4(ambient + diffuse + specular, 1.0);
            }

            ENDHLSL
        }
    }
}
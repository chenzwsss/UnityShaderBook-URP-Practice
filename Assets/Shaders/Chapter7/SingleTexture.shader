Shader "URP Practice/Chapter 7/SingleTexture"
{
    Properties
    {
        _Color("Color Tint", Color) = (1, 1, 1, 1)
        _BaseMap("Base Map", 2D) = "white" {}
        _Specular("Specular", Color) = (1, 1, 1, 1)
        _Gloss("Gloss", Range(8.0, 256)) = 20
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }

        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                half4 _Specular;
                half _Gloss;
                float4 _BaseMap_ST;
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

                //               * Tiling                + Offset
                OUT.uv = IN.uv.xy * _BaseMap_ST.xy + _BaseMap_ST.zw;
                // Or just call the built-in function
                // OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // normal in WS
                half3 normalWS = normalize(IN.normalWS);

                Light mainLight = GetMainLight();
                // light direction in WS
                half3 lightDirectionWS = normalize(mainLight.direction);
                // base map
                half3 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv).rgb * _Color.rgb;
                // ambient
                half3 ambient = SampleSH(normalWS) * albedo;
                // diffuse
                half3 diffuse = mainLight.color * albedo * max(dot(normalWS, lightDirectionWS), 0.0);
                // specular
                half3 viewDirectionWS = normalize(GetWorldSpaceViewDir(IN.positionWS));
                half3 halfDir = normalize(lightDirectionWS + viewDirectionWS);
                half3 specular = mainLight.color * _Specular.rgb * pow(max(dot(normalWS, halfDir), 0.0), _Gloss);

                return half4(ambient + diffuse + specular, 1.0);
            }

            ENDHLSL
        }
    }
}
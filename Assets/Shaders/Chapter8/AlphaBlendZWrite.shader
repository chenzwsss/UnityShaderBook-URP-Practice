Shader "URP Practice/Chapter 8/AlphaBlendZWrite"
{
    Properties
    {
        _Color("Color Tint", Color) = (1, 1, 1, 1)
        _BaseMap("Base Map", 2D) = "white" {}
        _AlphaScale("Alpha Scale", Range(0, 1)) = 1
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderPipeline"="UniversalRenderPipeline" }

        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                half4 _BaseMap_ST;
                half _AlphaScale;
            CBUFFER_END
        ENDHLSL

        // Extra pass that renders to depth buffer only
        Pass
        {
            ZWrite On
            ColorMask 0
        }

        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            ZWrite Off
            // Blend SrcAlpha OneMinusSrcAlpha
            Blend SrcAlpha OneMinusSrcAlpha, SrcAlpha OneMinusSrcAlpha

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
                float2 uv : TEXCOORD1;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normal);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 normalWS = normalize(IN.normalWS);
                Light mainLight = GetMainLight();
                half3 lightDirectionWS = normalize(mainLight.direction);

                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                albedo.rgb *= _Color.rgb;

                half3 ambient = SampleSH(normalWS) * albedo.rgb;

                half3 diffuse = mainLight.color * albedo.rgb * max(dot(normalWS, lightDirectionWS), 0.0);

                return half4(ambient + diffuse, albedo.a * _AlphaScale);
            }

            ENDHLSL
        }
    }
}
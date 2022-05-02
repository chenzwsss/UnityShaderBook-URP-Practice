Shader "URP Practice/Chapter 7/Normal Map In World Space"
{
    Properties
    {
        _Color("Color Tint", Color) = (1, 1, 1, 1)
        _BaseMap("Base Map", 2D) = "white" {}
        _NormalMap("Normal Map", 2D) = "normal" {}
        _NormalScale("Normal Scale", Float) = 1.0
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
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                half4 _BaseMap_ST;
                half4 _NormalMap_ST;
                half _NormalScale;
                half4 _Specular;
                half _Gloss;
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
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float4 uv : TEXCOORD0;
                float4 TtoW0 : TEXCOORD1;
                float4 TtoW1 : TEXCOORD2;
                float4 TtoW2 : TEXCOORD3;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

                OUT.uv.xy = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.uv.zw = TRANSFORM_TEX(IN.uv, _NormalMap);

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(IN.normal);
                float3 tangentWS = TransformObjectToWorldDir(IN.tangent.xyz);
                float3 bitangentWS = cross(normalWS, tangentWS) * IN.tangent.w;

                OUT.TtoW0 = float4(tangentWS.x, bitangentWS.x, normalWS.x, positionWS.x);
                OUT.TtoW1 = float4(tangentWS.y, bitangentWS.y, normalWS.y, positionWS.y);
                OUT.TtoW2 = float4(tangentWS.z, bitangentWS.z, normalWS.z, positionWS.z);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float3 positionWS = float3(IN.TtoW0.w, IN.TtoW1.w, IN.TtoW2.w);

                Light mainLight = GetMainLight();
                half3 lightDirectionWS = normalize(mainLight.direction);
                half3 viewDirectionWS = normalize(GetWorldSpaceViewDir(positionWS));

                half4 packedNormal = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.uv.zw);
                half3 normal = UnpackNormal(packedNormal);
                normal.xy *= _NormalScale;
                normal.z  = sqrt(1.0 - max(dot(normal.xy, normal.xy), 0.0));

                half3 normalWS = normalize(half3(dot(IN.TtoW0.xyz, normal), dot(IN.TtoW1.xyz, normal), dot(IN.TtoW2.xyz, normal)));

                half3 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv.xy).rgb * _Color.rgb;

                half3 ambient = SampleSH(normalWS) * albedo;

                half3 diffuse = mainLight.color * albedo * max(dot(normalWS, lightDirectionWS), 0.0);

                half3 halfDir = normalize(lightDirectionWS + viewDirectionWS);
                half3 specular = mainLight.color * _Specular.rgb * pow(max(dot(normalWS, halfDir), 0.0), _Gloss);

                return half4(ambient + diffuse + specular, 1.0);
            }

            ENDHLSL
        }
    }
}
Shader "URP Practice/Chapter 7/Normal Map In Tangent Space"
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
                float3 lightDirectionTS : TEXCOORD1;
                float3 viewDirTS : TEXCOORD2;
                float3 normalWS : TEXCOORD3;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

                OUT.uv.xy = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.uv.zw = TRANSFORM_TEX(IN.uv, _NormalMap);

                float3 binormal = cross(normalize(IN.normal), normalize(IN.tangent.xyz)) * IN.tangent.w;

                float3x3 rotation = float3x3(IN.tangent.xyz, binormal, IN.normal);

                Light mainLight = GetMainLight();
                // lightDir in OS
                float3 lightDirOS = TransformWorldToObject(mainLight.direction);
                // transform lightDir object space to tangent space
                OUT.lightDirectionTS = mul(rotation, lightDirOS);

                // camera positon in object space
                float3 cameraPosOS = TransformWorldToObject(GetCameraPositionWS());
                // view dir in object space
                float3 viewDirOS = cameraPosOS - IN.positionOS.xyz;

                // transform viewDir object space to Tangent Space
                OUT.viewDirTS = mul(rotation, viewDirOS);

                OUT.normalWS = TransformObjectToWorldNormal(IN.normal);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 lightDirectionTS = normalize(IN.lightDirectionTS);
                half3 viewDirTS = normalize(IN.viewDirTS);
                half3 normalWS = normalize(IN.normalWS);

                // sample bump map
                half4 packedNormal = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.uv.zw);
                half3 normalTS = UnpackNormal(packedNormal);
                normalTS.xy *= _NormalScale;
                normalTS.z = sqrt(1.0 - max(dot(normalTS.xy, normalTS.xy), 0.0));

                half3 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv.xy).rgb * _Color.rgb;

                half3 ambient = SampleSH(normalWS) * albedo;

                Light mainLight = GetMainLight();

                half3 diffuse = mainLight.color * albedo * max(dot(normalTS, lightDirectionTS), 0.0);

                half3 halfDirTS = normalize(lightDirectionTS + viewDirTS);
                half3 specular = mainLight.color * _Specular.rgb * pow(max(dot(normalTS, halfDirTS), 0.0), _Gloss);

                return half4(ambient + diffuse + specular, 1.0);
            }

            ENDHLSL
        }
    }
}
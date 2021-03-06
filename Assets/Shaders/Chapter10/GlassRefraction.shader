Shader "URP Practice/Chapter 10/GlassRefraction"
{
    Properties
    {
        _BaseMap("Base Map", 2D) = "white" {}
        _BumpMap("Normal Map", 2D) = "bump" {}
        _Cubemap("Environment Cubemap", Cube) = "_Skybox" {}
        _Distortion("Distortion", Range(0.0, 100.0)) = 10.0
        _RefractAmount("Refract Amount", Range(0.0, 1.0)) = 1.0
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);
            samplerCUBE _Cubemap;

            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseMap_ST;
                half4 _BumpMap_ST;
                half4 _CameraOpaqueTexture_TexelSize;
                float _Distortion;
                half _RefractAmount;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float4 uv : TEXCOORD1; // uv.xy: _BaseMap UV, uv.zw: _BumpMap UV
                float3 normalWS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 bitangentWS : TEXCOORD4;
                float4 positionNDC : TEXCOORD5;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;

                // output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                // output.positionWS = TransformObjectToWorld(input.positionOS.xyz);

                // output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                // output.tangentWS = TransformObjectToWorldDir(input.tangentOS.xyz);
                // output.bitangentWS = cross(output.normalWS, output.tangentWS) * input.tangentOS.w;

                // ??????????????????UV
                output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap);
                // ??????????????????UV
                output.uv.zw = TRANSFORM_TEX(input.texcoord, _BumpMap);
                // ?????????????????????????????????
                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS  = positionInputs.positionCS;
                output.positionWS  = positionInputs.positionWS;
                // ????????????????????????????????????, ??????????????????????????????
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.normalWS = normalInput.normalWS;
                output.tangentWS = normalInput.tangentWS;
                output.bitangentWS = normalInput.bitangentWS;

                output.positionNDC = positionInputs.positionNDC;

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // ?????????Unpack????????????
                half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv.zw));
                // ????????????????????????????????????
                half3 normalWS = normalize(TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz)));

                float2 offset = normalTS.xy * _Distortion * _CameraOpaqueTexture_TexelSize.xy;

                input.positionNDC.xy = offset * input.positionNDC.z + input.positionNDC.xy;
                // ????????????
                float2 screenUV = input.positionNDC.xy / input.positionNDC.w;

                half3 refraction = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenUV).rgb;

                half3 viewDirectionWS = normalize(GetWorldSpaceViewDir(input.positionWS));

                half3 reflectDir = reflect(-viewDirectionWS, normalWS);

                half3 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv.xy).rgb;

                half3 reflection = texCUBE(_Cubemap, reflectDir).rgb;

                half3 finalColor = reflection * (1 - _RefractAmount) + refraction * _RefractAmount;

                return half4(finalColor, 1.0);
            }

            ENDHLSL
        }
    }
}
Shader "URP Practice/Chapter 11/Water"
{
    Properties
    {
        // 河流纹理
        _BaseMap ("Base Map", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        // 水流波动的幅度
        _Magnitude ("Distortion Mannitude", Float) = 1
        // 波动频率
        _Frequency ("Distortion Frequency", Float) = 1
        // 波长的倒数( _InvWaveLength 越大, 波长越小)
        _InvWaveLength ("Distortion Inverse Wave Length", Float) = 10
        // 河流纹理的移动速度
        _Speed ("Speed", Float) = 0.5
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"
            "RenderPipeline"="UniversalPipelien" "DisableBatching"="True" }

        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half _Magnitude;
                half _Frequency;
                half _InvWaveLength;
                half _Speed;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varyings vert (Attributes input)
            {
                Varyings output;

                float3 offset = float3(0.0, 0.0, 0.0);

                // offset.x = sin(_Frequency * _Time.y + input.positionOS.x * _InvWaveLength + input.positionOS.y * _InvWaveLength + input.positionOS.z * _InvWaveLength) * _Magnitude;

                offset.x = sin(_Frequency * _Time.y + input.positionOS.z * _InvWaveLength) * _Magnitude;

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz + offset);

                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.uv += float2(0.0, _Time.y * _Speed);

                return output;
            }

            half4 frag (Varyings input) : SV_Target
            {
                // sample the texture
                half4 col = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                col.rgb *= _BaseColor.rgb;

                return col;
            }
            ENDHLSL
        }
    }
}

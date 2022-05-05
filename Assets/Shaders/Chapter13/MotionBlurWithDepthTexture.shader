Shader "URP Practice/Chapter 13/MotionBlurWithDepthTexture"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _BlurSize ("Blur Size", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        // TEXTURE2D_FLOAT(_CameraDepthTexture);
        // SAMPLER(sampler_CameraDepthTexture);

        CBUFFER_START(UnityPerMaterial)
            float4x4 _PreviousViewProjectionMatrix;
            float4x4 _CurrentViewProjectionInverseMatrix;
            float4 _MainTex_TexelSize;
            half _BlurSize;
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
            float2 uv_depth : TEXCOORD1;
        };

        Varyings vert(Attributes input)
        {
            Varyings output;
            output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
            output.uv = input.texcoord;
            output.uv_depth = input.texcoord;
            #if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0)
                output.uv_depth.y = 1 - output.uv_depth.y;
            #endif
            return output;
        }

        half4 frag(Varyings input) : SV_Target
        {
            // Get the depth buffer value at this pixel.
            float d = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv_depth).r;
            #if defined(UNITY_REVERSED_Z)
                d = 1.0 - d;
            #endif
            // H is the viewport position at this pixel in the range -1 to 1.
            float4 H = float4(input.uv.x * 2 - 1, input.uv.y * 2 - 1, d * 2 - 1, 1);
            // Transform by the view-projection inverse.
            float4 D = mul(_CurrentViewProjectionInverseMatrix, H);
            // Divide by w to get the world position. 
            float4 worldPos = D / D.w;
            
            // Current viewport position 
            float4 currentPos = H;
            // Use the world position, and transform by the previous view-projection matrix.  
            float4 previousPos = mul(_PreviousViewProjectionMatrix, worldPos);
            // Convert to nonhomogeneous points [-1,1] by dividing by w.
            previousPos /= previousPos.w;
            
            // Use this frame's position and last frame's to compute the pixel velocity.
            float2 velocity = (currentPos.xy - previousPos.xy)/2.0;
            
            float2 uv = input.uv;
            float4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
            uv += velocity * _BlurSize;
            for (int it = 1; it < 3; it++, uv += velocity * _BlurSize) {
                float4 currentColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                c += currentColor;
            }
            c /= 3;
            
            return half4(c.rgb, 1.0);
        }

        ENDHLSL

        Pass {
            ZTest Always Cull Off ZWrite Off

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            ENDHLSL
        }
    }
    FallBack Off
}

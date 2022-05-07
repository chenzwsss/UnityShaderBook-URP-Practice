Shader "URP Practice/Chapter 15/WaterWave"
{
    Properties
    {
        // 水面颜色
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        // 水面波纹材质纹理
        _MainTex ("Texture", 2D) = "white" {}
        // 由噪声纹理生成的法线纹理
        _WaveMap ("Wave Map", 2D) = "bump" {}
        // 模拟反射的立方体纹理
        _Cubemap ("Emvironment Cubemap", Cube) = "_Skybox" {}
        // 法线纹理在 X 方向的平移速度
        _WaveXSpeed ("Wave Horizontal Speed", Range(-0.1, 0.1)) = 0.01
        // 法线纹理在 Y 方向的平移速度
        _WaveYSpeed ("Wave Vertical Speed", Range(-0.1, 0.1)) = 0.01
        // 模拟折射时图像的扭曲程度
        _Distortion ("Distortion", Range(0.0, 100.0)) = 10.0
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Opaque" }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_WaveMap);
            SAMPLER(sampler_WaveMap);
            samplerCUBE _Cubemap;

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _WaveMap_ST;
                float4 _CameraOpaqueTexture_TexelSize;
                half4 _Color;
                half _WaveXSpeed;
                half _WaveYSpeed;
                float _Distortion;
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
                float3 normalWS : TEXCOORD1;
                float3 tangentWS : TEXCOORD2;
                float3 bitangentWS : TEXCOORD3;
                float4 uv : TEXCOORD4;
                float4 positionNDC : TEXCOORD5;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;

                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.tangentWS = TransformObjectToWorld(input.tangentOS.xyz);
                output.bitangentWS = cross(output.normalWS, output.tangentWS) * input.tangentOS.w;

                output.uv.xy = TRANSFORM_TEX(input.texcoord, _MainTex);
                output.uv.zw = TRANSFORM_TEX(input.texcoord, _WaveMap);

                output.positionNDC = vertexInput.positionNDC;

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // 计算法线纹理偏移量 speed
                float2 speed = _Time.y * float2(_WaveXSpeed, _WaveYSpeed);
                // 利用该偏移量 speed 对法线纹理进行两次采样(这是为了模拟两层交叉的水面波动的效果)
                half3 normalTS1 = UnpackNormal(SAMPLE_TEXTURE2D(_WaveMap, sampler_WaveMap, input.uv.zw + speed));
                half3 normalTS2 = UnpackNormal(SAMPLE_TEXTURE2D(_WaveMap, sampler_WaveMap, input.uv.zw - speed));
                // 对两次结果相加并归一化后得到切线空间下的法线方向
                half3 normalTS = normalize(normalTS1 + normalTS2);

                // 使用该值和 _Distortion 属性以及 _RefractionTex_TexeISize 来对屏幕图像的采样坐标进行偏移，模拟折射效果
                // _Distortion 值越大，偏移量越大，水面背后的物体看起来变形程度越大

                // 在这里，选择使用切线空间下的法线方向来进行偏移，是因为该空间下的法线可以反映顶点局部空间下的法线方向。
                // 需要注意的是，在计算偏移后的屏幕坐标时，把偏移量和屏幕坐标的 z 分量相乘，这是为了模拟深度越大、折射程度越大的效果
                float2 offset = normalTS.xy * _Distortion * _CameraOpaqueTexture_TexelSize.xy;
                input.positionNDC.xy = offset * input.positionNDC.z + input.positionNDC.xy;
                half3 refrCol = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, input.positionNDC.xy/input.positionNDC.w).rgb;

                half3 normalWS = normalize(TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz)));

                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv.xy);
                half3 viewDirectionWS = normalize(GetWorldSpaceViewDir(input.positionWS));

                half3 reflDir = reflect(-viewDirectionWS, normalWS);
                half3 reflCol = texCUBE(_Cubemap, reflDir).rgb * texColor.rgb * _Color.rgb;

                // 计算菲涅耳系数
                half fresnel = pow(1 - saturate(dot(viewDirectionWS, normalWS)), 4);

                half3 finalColor = reflCol * fresnel + refrCol * (1 - fresnel);

                return half4(finalColor, 1.0);
            }

            ENDHLSL
        }
    }
}

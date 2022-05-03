Shader "URP Practice/Chapter 11/Billboard"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _BaseMap ("Albedo (RGB)", 2D) = "white" {}
        // 用于调整是固定法线还是固定指向上的方向, 即约束垂直方向的程度
        _VerticalBillboarding ("Vertical Restraints", Range(0.0, 1.0)) = 1.0
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
                half _VerticalBillboarding;
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

                // 广告牌技术的难点在于，如何根据需求来构建3个相互正交的基向量。计算过程通常是，
                // 我们首先会通过初始计算得到目标的表面法线(例如就是视角方向)和指向上的方向，而两者往往是不垂直的。
                // 但是，两者其中之一是固定的，例如当模拟草丛时，我们希望广告牌的指向上的方向永远是(0,1,0), 而法线方向应该随视角变化;
                // 而当模拟粒子效果时，我们希望广告牌的法线方向是固定的，即总是指向视角方向，指向上的方向则可以发生变化。
                Varyings output;

                // 模型空间原点
                float3 center = float3(0, 0, 0);
                // 模型空间下的相机位置
                float3 cameraPositionOS = TransformWorldToObject(GetCameraPositionWS());
                // 相机位置减去原点坐标 得到指向视角方向的法线
                float3 normalDir = cameraPositionOS - center;
                // _VerticalBillboarding=0时，法线方向时固定的，总是指向视角方向
                // _VerticalBillboarding=1时，向上方向时固定为(0, 1, 0)
                normalDir.y = normalDir.y * _VerticalBillboarding;
                normalDir = normalize(normalDir);
                // 计算向上的方向
                // 根据指向视角方向的法线的 y 来定义一个与法线不同线的向量 tempDir
                float3 tempDir = abs(normalDir.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);
                // tempDir 和 normalDir 叉乘得到垂直于法线和 tempDir 的 rightDir
                float3 rightDir = normalize(cross(tempDir, normalDir));
                // normalDir 和 rightDir 叉乘得到垂直于法线和 rightDir 的 upDir
                float3 upDir = normalize(cross(normalDir, rightDir));

                // 得到3个相互正交的基向量 rightDir, upDir, normalDir
                // 计算在新的坐标系下 模型的位置坐标 positionNewOS
                float3 centerOffs = input.positionOS.xyz - center;
                float3 positionNewOS = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;

                output.positionCS = TransformObjectToHClip(positionNewOS);

                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

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

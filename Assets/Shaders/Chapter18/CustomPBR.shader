Shader "URP Practice/Chapter 18 /CustomPBR"
{
    Properties
    {
        // 基础颜色
        _Color ("Base (RGB)", Color) = (1, 1, 1, 1)
        // 基础纹理
        _MainTex ("Texture", 2D) = "white" {}
        // _SpecGlossMap RGB通道值和 _SpecColor 控制高光反射颜色; _SpecGlossMap A通道和 _Glossiness 控制材质的粗糙度
        _Glossiness ("Smoothness", Range(0.0, 1.0)) = 0.5
        _SpecColor ("Specular", Color) = (0.2, 0.2, 0.2, 1)
        _SpecGlossMap ("Speculr (RGB) Smoothness (A)", 2D) = "white" {}
        // 法线纹理
        _BumpMap ("Normal Map", 2D) = "bump" {}
        // 控制法线纹理的凹凸程度
        _BumpScale ("Bump Scale", Float) = 1.0
        // 自发光
        _EmissionColor ("Emmision Color", Color) = (0, 0, 0)
        _EmissionMap ("Emission", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        LOD 300

        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM

            #pragma target 3.0

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);
            TEXTURE2D(_EmissionMap);
            SAMPLER(sampler_EmissionMap);
            TEXTURE2D(_SpecGlossMap);
            SAMPLER(sampler_SpecGlossMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                float4 _MainTex_ST;
                float4 _BumpMap_ST;
                float4 _EmissionMap_ST;
                float4 _SpecGlossMap_ST;
                half4 _SpecColor;
                half4 _EmissionColor;
                half _Glossiness;
                half _BumpScale;
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
                float2 uv : TEXCOORD4;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;

                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.normalWS = normalInput.normalWS;
                output.tangentWS = normalInput.tangentWS;
                output.bitangentWS = normalInput.bitangentWS;

                output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);

                return output;
            }

            // inline 的作用是用于告诉编译器应该尽可能使用内联调用的方式来调用该函数，减少函数调用的开销
            inline half3 CustomDisneyDiffuseTerm(half NdotV, half NdotL, half LdotH, half roughness, half3 baseColor)
            {
                half fd90 = 0.5 + 2 * LdotH * LdotH * roughness;

                half lightScatter = (1 + (fd90 - 1) * pow(1 - NdotL, 5));
                half viewScatter = (1 + (fd90 - 1) * pow(1 - NdotV, 5));

                // INV_PI 圆周率 π 的倒数
                return baseColor * INV_PI * lightScatter * viewScatter;
            }

            // 可见性项 V，它计算的是阴影-遮掩函数除以高光反射项的分母部分后的结果
            inline half CustomSmithJointGGXVisibilityTerm(half NdotL, half NdotV, half roughness)
            {
                // Original formulation:
                // lambda_v = (-1 + sqrt(a2 * (1 - NdotL2) / NdotL2 + 1)) * 0.5f;
                // lambda_l = (-1 + sqrt(a2 * (1 - NdotV2) / NdotV2 + 1)) * 0.5f;
                // G = 1 / (1 + lambda_v + lambda_l);

                // Approximation of the above formulation (simplify the sqrt, not mathematically correct but close enough)
                half a2 = roughness * roughness;
                half lambdaV = NdotL * (NdotV * (1 - a2) + a2);
                half lambdaL = NdotV * (NdotL * (1 - a2) + a2);

                return 0.5f / (lambdaV + lambdaL + 1e-5f);
            }

            // 法线分布项 D，CustomGGXTerm 函数的实现
            inline half CustomGGXTerm(half NdotH, half roughness)
            {
                half a2 = roughness * roughness;
                half d = (NdotH * a2 - NdotH) * NdotH + 1.0f;
                return INV_PI * a2 / (d * d + 1e-7f);
            }

            // 菲涅耳反射项 F，CustomFresnelTerm 函数
            inline half3 CustomFresnelTerm(half3 c, half cosA)
            {
                half t = pow(1 - cosA, 5);
                return c + (1 - c) * t;
            }

            inline half3 CustomFresnelLerp(half3 c0, half3 c1, half cosA)
            {
                half t = pow(1 - cosA, 5);
                return lerp(c0, c1, t);
            }

            half4 frag(Varyings input) : SV_Target
            {
                // Prepare all the inputs
                half4 specGloss = SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, input.uv);
                specGloss.a *= _Glossiness;
                // 高光反射颜色
                half3 specColor = specGloss.rgb * _SpecColor.rgb;
                // 粗糙度
                half roughness = 1 - specGloss.a;

                half oneMinusReflectivity = 1 - max(max(specColor.r, specColor.g), specColor.b);

                half3 diffColor = _Color.rgb * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv).rgb * oneMinusReflectivity;

                half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv));
                normalTS.xy *= _BumpScale;

                half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz);
                half3 normalWS = normalize(TransformTangentToWorld(normalTS, tangentToWorld));

                Light mainLight = GetMainLight();
                half3 lightDirectionWS = normalize(mainLight.direction);
                half3 viewDirectionWS = normalize(GetWorldSpaceViewDir(input.positionWS));

                half3 reflectionWS = normalize(reflect(-viewDirectionWS, normalWS));

                half3 halfDir = normalize(lightDirectionWS + viewDirectionWS);

                // Compute BRDF terms
                half NV = saturate(dot(normalWS, viewDirectionWS));
                half NL = saturate(dot(normalWS, lightDirectionWS));
                half NH = saturate(dot(normalWS, halfDir));
                half LV = saturate(dot(lightDirectionWS, viewDirectionWS));
                half LH = saturate(dot(lightDirectionWS, halfDir));

                // Diffuse term
                half3 diffuseTerm = CustomDisneyDiffuseTerm(NV, NL, LH, roughness, diffColor);

                // Specular term
                half V = CustomSmithJointGGXVisibilityTerm(NL, NV, roughness);
                half D = CustomGGXTerm(NH, roughness * roughness);
                half F = CustomFresnelTerm(specColor, LH);
                half3 specularTerm = F * V * D;

                // Emission term
                half3 emisstionTerm = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, input.uv).rgb * _EmissionColor.rgb;

                // 基于图像的光照部分(IBL)
                // unity_SpecCube0 包含了该物体周围当前活跃的反射探针(Reflection Probe)中所包含的环境贴图。
                // 尽管我们没有在场景中手动放置任何反射探针，但 Unity 会根据 Window -> Lighting -> Skybox 中的设置，在场景中生成一个默认的反射探针。
                // 由于在本节的准备 工作中我们在 Window -> Lighting -> Skybox 中设置了自定义的天空盒，因此此时 unity_SpecCube0 中包含的就是这个自定义天空盒的环境贴图。
                // 如果我们在场景中放置了其他反射探针，Unity 则会 根据相关设置和物体所在的位置自动把距离该物体最近的一个或几个反射探针数据传递给 Shader
                half perceptualRoughness =roughness * (1.7 - 0.7 * roughness);
                half mip = perceptualRoughness * 6;

                reflectionWS = BoxProjectedCubemapDirection(reflectionWS, input.positionWS, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
                half3 envMap = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectionWS, mip).rgb;
                half grazingTerm = saturate((1 - roughness) + (1 - oneMinusReflectivity));
                half surfaceReduction = 1.0 / (roughness * roughness + 1.0);
                // 为了给 IBL 添加更加真实的菲涅耳反射，我们对高光反射颜色 specColor 和掠射颜色 grazingTerm 进行菲涅耳插值。
                // 掠射颜色 grazingTerm 是由材质粗糙度和之前计算得到的 oneMinusReflectivity 共同决定的。
                // 使用掠射角度进行菲涅耳插值的好处是，我们可以在掠射角得 到更加真实的菲涅耳反射效果，同时还考虑了材质粗糙度的影响。
                // 除此之外，我们还使用了由粗 糙度计算得到的 surfaceReduction 参数进一步对 IBL 的进行修正
                half3 indirectSpecular = surfaceReduction * envMap * CustomFresnelLerp(specColor, grazingTerm, NV);

                half3 col = emisstionTerm + PI * (diffuseTerm + specularTerm) * mainLight.color * NL * mainLight.distanceAttenuation + indirectSpecular;

                return half4(col, 1.0);
            }

            ENDHLSL
        }
    }
}

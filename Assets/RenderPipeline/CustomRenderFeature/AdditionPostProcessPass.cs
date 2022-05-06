using UnityEngine.Experimental.Rendering;

namespace UnityEngine.Rendering.Universal
{
    /// <summary>
    /// 附加的后处理Pass
    /// </summary>
    public class AdditionPostProcessPass : ScriptableRenderPass
    {
        //标签名，用于续帧调试器中显示缓冲区名称
        const string CommandBufferTag = "AdditionalPostProcessing Pass";

        // 用于后处理的材质
        Material m_BlitMaterial;
        AdditionalMaterialLibrary m_Materials;
        AdditionalPostProcessData m_Data;

        // 主纹理信息
        RenderTargetIdentifier m_Source;
        // 深度信息
        RenderTargetIdentifier m_Depth;
        // 当前帧的渲染纹理描述
        RenderTextureDescriptor m_Descriptor;
        // 目标相机信息
        RenderTargetHandle m_Destination;

        // 临时的渲染目标
        RenderTargetHandle m_TempRT0;
        // 临时的渲染目标
        RenderTargetHandle m_TempRT1;
        RenderTargetHandle m_TempRT2;

        // 属性参数组件
        BrightnessSaturationContrast m_BrightnessSaturationContrast;

        /// 这里扩展后续的属性参数组件引用

        EdgeDetection m_EdgeDetection;
        GaussianBlur m_GaussianBlur;
        Bloom m_Bloom;

        MotionBlur m_MotionBlur;
        private RenderTexture motionBlurLastRT;

        MotionBlurWithDepthTexture m_MotionBlurWithDepthTexture;
        private Matrix4x4 previousViewProjectionMatrix;
        private Camera camera;

        FogWithDepthTexture m_FogWithDepthTexture;

        EdgeDetectNormalsAndDepth m_EdgeDetectNormalsAndDepth;

        public AdditionPostProcessPass(RenderPassEvent evt, AdditionalPostProcessData data, Material blitMaterial = null)
        {
            renderPassEvent = evt;
            m_Data = data;
            m_Materials = new AdditionalMaterialLibrary(data);
            m_BlitMaterial = blitMaterial;

            m_TempRT0.Init("_TemporaryRenderTexture0");
            m_TempRT1.Init("_TemporaryRenderTexture1");
            m_TempRT2.Init("_TemporaryRenderTexture2");
        }

        public void Setup(in RenderTextureDescriptor baseDescriptor, in RenderTargetIdentifier source, in RenderTargetIdentifier depth, in RenderTargetHandle destination)
        {
            m_Descriptor = baseDescriptor;
            m_Source = source;

            m_Depth = depth;
            m_Destination = destination;

            camera = GameObject.Find("Main Camera").GetComponent<Camera>();
            previousViewProjectionMatrix = camera.projectionMatrix * camera.worldToCameraMatrix;
        }


        /// <summary>
        /// URP会自动调用该执行方法
        /// </summary>
        /// <param name="context"></param>
        /// <param name="renderingData"></param>
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // 从Volume框架中获取所有堆栈
            var stack = VolumeManager.instance.stack;
            // 从堆栈中查找对应的属性参数组件
            m_BrightnessSaturationContrast = stack.GetComponent<BrightnessSaturationContrast>();

            /// 这里扩展后续的属性参数组件获取
            m_EdgeDetection = stack.GetComponent<EdgeDetection>();
            m_GaussianBlur = stack.GetComponent<GaussianBlur>();
            m_Bloom = stack.GetComponent<Bloom>();
            m_MotionBlur = stack.GetComponent<MotionBlur>();
            m_MotionBlurWithDepthTexture = stack.GetComponent<MotionBlurWithDepthTexture>();
            m_FogWithDepthTexture = stack.GetComponent<FogWithDepthTexture>();
            m_EdgeDetectNormalsAndDepth = stack.GetComponent<EdgeDetectNormalsAndDepth>();

            // 从命令缓冲区池中获取一个带标签的渲染命令，该标签名可以在后续帧调试器中见到
            var cmd = CommandBufferPool.Get(CommandBufferTag);

            // 调用渲染函数
            Render(cmd, ref renderingData);

            // 执行命令缓冲区
            context.ExecuteCommandBuffer(cmd);
            // 释放命令缓存
            CommandBufferPool.Release(cmd);
        }

        // 渲染
        void Render(CommandBuffer cmd, ref RenderingData renderingData)
        {
            ref var cameraData = ref renderingData.cameraData;
            bool m_IsStereo = renderingData.cameraData.isStereoEnabled;
            bool isSceneViewCamera = cameraData.isSceneViewCamera;

            // VolumeComponent是否开启，且非Scene视图摄像机
            // 亮度、对比度、饱和度
            if (m_BrightnessSaturationContrast.IsActive() && !isSceneViewCamera)
            {
                SetBrightnessSaturationContrast(cmd, m_Materials.brightnessSaturationContrast);
            }

            /// 这里扩展后续的后处理方法的开关校验
            if (m_EdgeDetection.IsActive() && !isSceneViewCamera)
            {
                SetEdgeDetection(cmd, m_Materials.edgeDetection);
            }
            if (m_GaussianBlur.IsActive() && !isSceneViewCamera)
            {
                SetGaussianBlur(cmd, m_Materials.gaussianBlur);
            }
            if (m_Bloom.IsActive() && !isSceneViewCamera)
            {
                SetBloom(cmd, m_Materials.bloom);
            }
            if (m_MotionBlur.IsActive() && !isSceneViewCamera)
            {
                SetMotionBlur(cmd, m_Materials.motionBlur);
            }
            if (m_MotionBlurWithDepthTexture.IsActive() && !isSceneViewCamera)
            {
                SetMotionBlurWithDepthTexture(cmd, m_Materials.motionBlurWithDepthTexture);
            }
            if (m_FogWithDepthTexture.IsActive() && !isSceneViewCamera)
            {
                SetFogWithDepthTexture(cmd, m_Materials.fogWithDepthTexture);
            }
            if (m_EdgeDetectNormalsAndDepth.IsActive() && !isSceneViewCamera)
            {
                SetEdgeDetectNormalsAndDepth(cmd, m_Materials.edgeDetectNormalsAndDepth);
            }
        }

        RenderTextureDescriptor GetStereoCompatibleDescriptor(int width, int height, int depthBufferBits = 0)
        {
            var desc = m_Descriptor;
            desc.depthBufferBits = depthBufferBits;
            desc.msaaSamples = 1;
            desc.width = width;
            desc.height = height;
            return desc;
        }


        #region 处理材质渲染
        // 亮度、饱和度、对比度渲染
        void SetBrightnessSaturationContrast(CommandBuffer cmd, Material uberMaterial)
        {
            // 写入参数
            uberMaterial.SetFloat("_Brightness", m_BrightnessSaturationContrast.brightness.value);
            uberMaterial.SetFloat("_Saturation", m_BrightnessSaturationContrast.saturation.value);
            uberMaterial.SetFloat("_Contrast", m_BrightnessSaturationContrast.contrast.value);

            // 通过目标相机的渲染信息创建临时缓冲区
            //RenderTextureDescriptor opaqueDesc = m_Descriptor;
            //opaqueDesc.depthBufferBits = 0;
            //cmd.GetTemporaryRT(m_TempRT0.id, opaqueDesc);
            //or
            int tw = m_Descriptor.width;
            int th = m_Descriptor.height;
            var desc = GetStereoCompatibleDescriptor(tw, th);
            cmd.GetTemporaryRT(m_TempRT0.id, desc, FilterMode.Bilinear);

            // 通过材质，将计算结果存入临时缓冲区
            cmd.Blit(m_Source, m_TempRT0.Identifier(), uberMaterial);
            // 再从临时缓冲区存入主纹理
            cmd.Blit(m_TempRT0.Identifier(), m_Source);

            // 释放临时RT
            cmd.ReleaseTemporaryRT(m_TempRT0.id);
        }

        /// 这里扩展后处理对材质填充方法

        void SetEdgeDetection(CommandBuffer cmd, Material uberMaterial)
        {
            // 写入参数
            uberMaterial.SetFloat("_EdgeOnly", m_EdgeDetection.edgeOnly.value);
            uberMaterial.SetColor("_EdgeColor", m_EdgeDetection.edgeColor.value);
            uberMaterial.SetColor("_BackgroundColor", m_EdgeDetection.backgroundColor.value);

            int tw = m_Descriptor.width;
            int th = m_Descriptor.height;
            var desc = GetStereoCompatibleDescriptor(tw, th);
            cmd.GetTemporaryRT(m_TempRT0.id, desc, FilterMode.Bilinear);

            // 通过材质，将计算结果存入临时缓冲区
            cmd.Blit(m_Source, m_TempRT0.Identifier(), uberMaterial);
            // 再从临时缓冲区存入主纹理
            cmd.Blit(m_TempRT0.Identifier(), m_Source);

            // 释放临时RT
            cmd.ReleaseTemporaryRT(m_TempRT0.id);
        }

        void SetGaussianBlur(CommandBuffer cmd, Material uberMaterial)
        {
            int rtW = m_Descriptor.width / m_GaussianBlur.downSample.value;
            int rtH = m_Descriptor.height / m_GaussianBlur.downSample.value;

            RenderTargetIdentifier buffer0, buffer1;
            var desc = GetStereoCompatibleDescriptor(rtW, rtH);
            cmd.GetTemporaryRT(m_TempRT0.id, desc, FilterMode.Bilinear);
            buffer0 = m_TempRT0.id;
            cmd.GetTemporaryRT(m_TempRT1.id, desc, FilterMode.Bilinear);
            buffer1 = m_TempRT1.id;

            // 将计算结果存入临时缓冲区0
            cmd.Blit(m_Source, buffer0);

            // 循环高斯模糊多次迭代多次
            for (int i = 0; i < m_GaussianBlur.iterations.value; ++i)
            {
                // 设置 Shader 变量 _BlurSize
                uberMaterial.SetFloat("_BlurSize", 1.0f  + i * m_GaussianBlur.blurSpread.value);
                // 第一个 Pass, 竖直方向模糊, 从临时缓冲区0到临时缓冲区1
                cmd.Blit(buffer0, buffer1, uberMaterial, 0);
                // 交换临时缓冲区1到临时缓冲区0
                CoreUtils.Swap(ref buffer0, ref buffer1);
                // 第二个 Pass, 水平方向模糊, 从临时缓冲区0到临时缓冲区1
                cmd.Blit(buffer0, buffer1, uberMaterial, 1);
                // 再次交换临时缓冲区1到临时缓冲区0, 进入下一个循环
                CoreUtils.Swap(ref buffer0, ref buffer1);
            }

            // 再从临时缓冲区0存入主纹理
            cmd.Blit(buffer0, m_Source);

            // 释放临时RT
            cmd.ReleaseTemporaryRT(m_TempRT0.id);
            cmd.ReleaseTemporaryRT(m_TempRT1.id);
        }

        void SetBloom(CommandBuffer cmd, Material uberMaterial)
        {
            uberMaterial.SetFloat("_LuminanceThreshold", m_Bloom.luminanceThreshold.value);

            int rtW = m_Descriptor.width / m_Bloom.downSample.value;
            int rtH = m_Descriptor.height / m_Bloom.downSample.value;

            RenderTargetIdentifier buffer0, buffer1;
            RenderTargetIdentifier buffer2;
            var desc = GetStereoCompatibleDescriptor(rtW, rtH);
            cmd.GetTemporaryRT(m_TempRT0.id, desc, FilterMode.Bilinear);
            buffer0 = m_TempRT0.id;
            cmd.GetTemporaryRT(m_TempRT1.id, desc, FilterMode.Bilinear);
            buffer1 = m_TempRT1.id;

            var descOri = GetStereoCompatibleDescriptor(m_Descriptor.width, m_Descriptor.height);
            cmd.GetTemporaryRT(m_TempRT2.id, descOri, FilterMode.Bilinear);
            buffer2 = m_TempRT2.id;
            // 存储原纹理
            cmd.Blit(m_Source, buffer2);

            // 第1个Pass, 根据设置的 _LuminanceThreshold 提取出亮的区域, 也就是要 Bloom 的区域, 存入 buffer0
            cmd.Blit(m_Source, buffer0, uberMaterial, 0);

            // 对提取后的 buffer0 进行高斯模糊
            for (int i = 0; i < m_Bloom.iterations.value; ++i)
            {
                // 设置 Shader 变量 _BlurSize
                uberMaterial.SetFloat("_BlurSize", 1.0f  + i * m_Bloom.blurSpread.value);
                // 第2个 Pass, 竖直方向模糊, 从 buffer0 到 buffer1
                cmd.Blit(buffer0, buffer1, uberMaterial, 1);
                // 交换 buffer1 到 buffer0
                CoreUtils.Swap(ref buffer0, ref buffer1);
                // 第3个 Pass, 水平方向模糊, 从 buffer0 到 buffer1
                cmd.Blit(buffer0, buffer1, uberMaterial, 2);
                // 再次交换 buffer1 到 buffer0, 进入下一个循环
                CoreUtils.Swap(ref buffer0, ref buffer1);
            }
            // 把高斯模糊后的提取出的 Bloom 传入 Shader 中
            cmd.SetGlobalTexture("_BloomTexture", buffer0);
            // 第4个 Pass, 把原纹理和处理后的提取出来的纹理相加, 最终就是 Bloom 效果
            cmd.Blit(buffer2, m_Source, uberMaterial, 3);

            // 释放临时RT
            cmd.ReleaseTemporaryRT(m_TempRT0.id);
            cmd.ReleaseTemporaryRT(m_TempRT1.id);
            cmd.ReleaseTemporaryRT(m_TempRT2.id);
        }

        void SetMotionBlur(CommandBuffer cmd, Material uberMaterial)
        {
            if (motionBlurLastRT == null || motionBlurLastRT.width != m_Descriptor.width || motionBlurLastRT.height != m_Descriptor.height)
            {
                Object.DestroyImmediate(motionBlurLastRT);
                motionBlurLastRT = new RenderTexture(m_Descriptor);
                motionBlurLastRT.hideFlags = HideFlags.HideAndDontSave;
                cmd.Blit(m_Source, motionBlurLastRT);
                // or
                // Blit(cmd, m_Source, motionBlurLastRT);
                return;
            }

            motionBlurLastRT.MarkRestoreExpected();
            uberMaterial.SetFloat("_BlurAmount", 1.0f - m_MotionBlur.blurAmount.value);

            cmd.Blit(m_Source, motionBlurLastRT, uberMaterial);
            cmd.Blit(motionBlurLastRT, m_Source);
        }

        void SetMotionBlurWithDepthTexture(CommandBuffer cmd, Material uberMaterial)
        {
            if (camera)
            {
                uberMaterial.SetFloat("_BlurSize", m_MotionBlurWithDepthTexture.blurSize.value);

                int tw = m_Descriptor.width;
                int th = m_Descriptor.height;
                var desc = GetStereoCompatibleDescriptor(tw, th);
                cmd.GetTemporaryRT(m_TempRT0.id, desc, FilterMode.Bilinear);

                cmd.SetGlobalMatrix("_PreviousViewProjectionMatrix", previousViewProjectionMatrix);
                Matrix4x4 currentViewProjectionMatrix = camera.projectionMatrix * camera.worldToCameraMatrix;
                Matrix4x4 currentViewProjectionInverseMatrix = currentViewProjectionMatrix.inverse;
                cmd.SetGlobalMatrix("_CurrentViewProjectionInverseMatrix", currentViewProjectionInverseMatrix);
                previousViewProjectionMatrix = currentViewProjectionMatrix;

                // 通过材质，将计算结果存入临时缓冲区
                cmd.Blit(m_Source, m_TempRT0.Identifier(), uberMaterial);
                // 再从临时缓冲区存入主纹理
                cmd.Blit(m_TempRT0.Identifier(), m_Source);

                // 释放临时RT
                cmd.ReleaseTemporaryRT(m_TempRT0.id);
            }
        }

        void SetFogWithDepthTexture(CommandBuffer cmd, Material uberMaterial)
        {
            if (camera)
            {
                Matrix4x4 frustumCorners = Matrix4x4.identity;
                Transform cameraTransform = camera.transform;

                // 相机的fov
                float fov = camera.fieldOfView;
                // 相机到近裁剪平面(屏幕)的距离
                float near = camera.nearClipPlane;
                // 近裁剪平面(屏幕)的宽高比(width/height)
                float aspect = camera.aspect;

                // 根据三角函数求出近裁剪平面一半的高度
                float halfHeight = near * Mathf.Tan(fov * 0.5f * Mathf.Deg2Rad);
                // right, up, forward 组成相机的三个单位向量
                // 求出 toTop 和 toRight
                Vector3 toTop = cameraTransform.up * halfHeight;
                Vector3 toRight = cameraTransform.right * halfHeight * aspect;

                // 近裁剪平面左上角 topLeft
                Vector3 topLeft = cameraTransform.forward * near + toTop - toRight;
                float scale = topLeft.magnitude / near;

                topLeft.Normalize();
                topLeft *= scale;

                Vector3 topRight = cameraTransform.forward * near + toRight + toTop;
                topRight.Normalize();
                toRight *= scale;

                Vector3 bottomLeft = cameraTransform.forward * near - toTop - toRight;
                bottomLeft.Normalize();
                bottomLeft *= scale;

                Vector3 bottomRight = cameraTransform.forward * near + toRight - toTop;
                bottomRight.Normalize();
                bottomRight *= scale;

                frustumCorners.SetRow(0, bottomLeft);
                frustumCorners.SetRow(1, bottomRight);
                frustumCorners.SetRow(2, topRight);
                frustumCorners.SetRow(3, topLeft);

                uberMaterial.SetMatrix("_FrustumCornersRay", frustumCorners);
                uberMaterial.SetFloat("_FogDensity", m_FogWithDepthTexture.fogDensity.value);
                uberMaterial.SetColor("_FogColor", m_FogWithDepthTexture.fogColor.value);
                uberMaterial.SetFloat("_FogStart", m_FogWithDepthTexture.fogStart.value);
                uberMaterial.SetFloat("_FogEnd", m_FogWithDepthTexture.fogEnd.value);

                int tw = m_Descriptor.width;
                int th = m_Descriptor.height;
                var desc = GetStereoCompatibleDescriptor(tw, th);
                cmd.GetTemporaryRT(m_TempRT0.id, desc, FilterMode.Bilinear);

                // 通过材质，将计算结果存入临时缓冲区
                cmd.Blit(m_Source, m_TempRT0.Identifier(), uberMaterial);
                // 再从临时缓冲区存入主纹理
                cmd.Blit(m_TempRT0.Identifier(), m_Source);

                // 释放临时RT
                cmd.ReleaseTemporaryRT(m_TempRT0.id);
            }
        }

        void SetEdgeDetectNormalsAndDepth(CommandBuffer cmd, Material uberMaterial)
        {
            uberMaterial.SetFloat("_EdgeOnly", m_EdgeDetectNormalsAndDepth.edgesOnly.value);
            uberMaterial.SetColor("_EdgeColor", m_EdgeDetectNormalsAndDepth.edgeColor.value);
            uberMaterial.SetColor("_BackgroundColor", m_EdgeDetectNormalsAndDepth.backgroundColor.value);
            uberMaterial.SetFloat("_SampleDistance", m_EdgeDetectNormalsAndDepth.sampleDistance.value);
            uberMaterial.SetVector("_Sensitivity", new Vector4(m_EdgeDetectNormalsAndDepth.sensitivityNormals.value,
                m_EdgeDetectNormalsAndDepth.sensitivityDepth.value, 0.0f, 0.0f));

            int tw = m_Descriptor.width;
            int th = m_Descriptor.height;
            var desc = GetStereoCompatibleDescriptor(tw, th);
            cmd.GetTemporaryRT(m_TempRT0.id, desc, FilterMode.Bilinear);

            // 通过材质，将计算结果存入临时缓冲区
            cmd.Blit(m_Source, m_TempRT0.Identifier(), uberMaterial);
            // 再从临时缓冲区存入主纹理
            cmd.Blit(m_TempRT0.Identifier(), m_Source);

            // 释放临时RT
            cmd.ReleaseTemporaryRT(m_TempRT0.id);
        }

        #endregion
    }
}

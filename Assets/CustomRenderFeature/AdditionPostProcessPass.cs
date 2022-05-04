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
        RenderTargetHandle m_TemporaryColorTexture01;


        // 属性参数组件
        BrightnessSaturationContrast m_BrightnessSaturationContrast;

        /// 这里扩展后续的属性参数组件引用

        EdgeDetection m_EdgeDetection;


        public AdditionPostProcessPass(RenderPassEvent evt, AdditionalPostProcessData data, Material blitMaterial = null)
        {
            renderPassEvent = evt;
            m_Data = data;
            m_Materials = new AdditionalMaterialLibrary(data);
            m_BlitMaterial = blitMaterial;
        }

        public void Setup(in RenderTextureDescriptor baseDescriptor, in RenderTargetIdentifier source, in RenderTargetIdentifier depth, in RenderTargetHandle destination)
        {
            m_Descriptor = baseDescriptor;
            m_Source = source;

            m_Depth = depth;
            m_Destination = destination;
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
            //cmd.GetTemporaryRT(m_TemporaryColorTexture01.id, opaqueDesc);
            //or
            int tw = m_Descriptor.width;
            int th = m_Descriptor.height;
            var desc = GetStereoCompatibleDescriptor(tw, th);
            cmd.GetTemporaryRT(m_TemporaryColorTexture01.id, desc, FilterMode.Bilinear);

            // 通过材质，将计算结果存入临时缓冲区
            cmd.Blit(m_Source, m_TemporaryColorTexture01.Identifier(), uberMaterial);
            // 再从临时缓冲区存入主纹理
            cmd.Blit(m_TemporaryColorTexture01.Identifier(), m_Source);

            // 释放临时RT
            cmd.ReleaseTemporaryRT(m_TemporaryColorTexture01.id);
        }

        /// 这里扩展后处理对材质填充方法

        void SetEdgeDetection(CommandBuffer cmd, Material uberMaterial)
        {
            // 写入参数
            uberMaterial.SetFloat("_EdgeOnly", m_EdgeDetection.edgeOnly.value);
            uberMaterial.SetColor("_EdgeColor", m_EdgeDetection.edgeColor.value);
            uberMaterial.SetColor("_BackgroundColor", m_EdgeDetection.backgroundColor.value);

            // 通过目标相机的渲染信息创建临时缓冲区
            //RenderTextureDescriptor opaqueDesc = m_Descriptor;
            //opaqueDesc.depthBufferBits = 0;
            //cmd.GetTemporaryRT(m_TemporaryColorTexture01.id, opaqueDesc);
            //or
            int tw = m_Descriptor.width;
            int th = m_Descriptor.height;
            var desc = GetStereoCompatibleDescriptor(tw, th);
            cmd.GetTemporaryRT(m_TemporaryColorTexture01.id, desc, FilterMode.Bilinear);

            // 通过材质，将计算结果存入临时缓冲区
            cmd.Blit(m_Source, m_TemporaryColorTexture01.Identifier(), uberMaterial);
            // 再从临时缓冲区存入主纹理
            cmd.Blit(m_TemporaryColorTexture01.Identifier(), m_Source);

            // 释放临时RT
            cmd.ReleaseTemporaryRT(m_TemporaryColorTexture01.id);
        }

        #endregion
    }
}

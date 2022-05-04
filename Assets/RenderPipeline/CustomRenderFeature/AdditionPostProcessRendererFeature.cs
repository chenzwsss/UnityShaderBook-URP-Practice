namespace UnityEngine.Rendering.Universal
{
    /// <summary>
    /// 可编程渲染功能
    /// 必须要继承ScriptableRendererFeature抽象类，
    /// 并且实现AddRenderPasses跟Create函数
    /// </summary>
    public class AdditionPostProcessRendererFeature : ScriptableRendererFeature
    {
        // 后处理Pass
        AdditionPostProcessPass postPass;
        // 保存Shader的对象引用
        public AdditionalPostProcessData postData;

        //在这里，您可以在渲染器中注入一个或多个渲染通道。
        //每个摄像机设置一次渲染器时，将调用此方法。
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (postPass == null)
            {
                return;
            }
            // 设置调用后处理Pass
            postPass.Setup(renderingData.cameraData.cameraTargetDescriptor, renderer.cameraColorTarget, renderer.cameraDepthTarget, RenderTargetHandle.CameraTarget);
            
            // 添加该Pass到渲染管线中
            renderer.EnqueuePass(postPass);
        }


        // 对象初始化时会调用该函数
        public override void Create()
        {
            postPass = new AdditionPostProcessPass(RenderPassEvent.AfterRenderingTransparents, postData);
        }
    }
}

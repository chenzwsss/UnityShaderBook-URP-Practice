namespace UnityEngine.Rendering.Universal
{
    /// <summary>
    /// 材质列表
    /// </summary>
    public class AdditionalMaterialLibrary
    {
        public readonly Material brightnessSaturationContrast;
        // 这里扩展后处理材质属性

        public readonly Material edgeDetection;

        public readonly Material gaussianBlur;

        public readonly Material bloom;

        public readonly Material motionBlur;

        public readonly Material motionBlurWithDepthTexture;

        public readonly Material fogWithDepthTexture;

        public readonly Material edgeDetectNormalsAndDepth;

        public readonly Material fogWithNoise;

        /// <summary>
        /// 初始化时从配置文件中获取材质
        /// </summary>
        /// <param name="data"></param>
        public AdditionalMaterialLibrary(AdditionalPostProcessData data)
        {
            brightnessSaturationContrast = Load(data.shaders.brightnessSaturationContrast);
            // 这里扩展后处理材质的加载

            edgeDetection = Load(data.shaders.edgeDetection);
            gaussianBlur = Load(data.shaders.gaussianBlur);
            bloom = Load(data.shaders.bloom);
            motionBlur = Load(data.shaders.motionBlur);
            motionBlurWithDepthTexture = Load(data.shaders.motionBlurWithDepthTexture);
            fogWithDepthTexture = Load(data.shaders.fogWithDepthTexture);
            edgeDetectNormalsAndDepth = Load(data.shaders.edgeDetectNormalsAndDepth);
            fogWithNoise = Load(data.shaders.fogWithNoise);
        }

        Material Load(Shader shader)
        {
            if (shader == null)
            {
                Debug.LogErrorFormat($"丢失 shader. {GetType().DeclaringType.Name} 渲染通道将不会执行。检查渲染器资源中是否缺少引用。");
                return null;
            }
            else if (!shader.isSupported)
            {
                return null;
            }
            return CoreUtils.CreateEngineMaterial(shader);
        }

        internal void Cleanup()
        {
            CoreUtils.Destroy(brightnessSaturationContrast);
        }
    }
}

using System;

namespace UnityEngine.Rendering.Universal
{
    /// <summary>
    /// 附加后处理数据
    /// </summary>
    [Serializable]
    public class AdditionalPostProcessData : ScriptableObject
    {
        [Serializable]
        public sealed class Shaders
        {
            public Shader brightnessSaturationContrast;
            //在这里扩展后续其他后处理Shader引用
        }
        public Shaders shaders;
    }   
}

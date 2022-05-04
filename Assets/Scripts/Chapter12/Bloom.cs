using System;

namespace UnityEngine.Rendering.Universal
{
    [Serializable, VolumeComponentMenu("Addition-Post-processing/Bloom")]
    public class Bloom : VolumeComponent, IPostProcessComponent
    {
        [Tooltip("开关")]
        public BoolParameter _Switch = new BoolParameter(false);

        [Tooltip("高斯模糊迭代次数")]
        public ClampedIntParameter iterations = new ClampedIntParameter(3, 0, 4);
        [Tooltip("模糊范围")]
        public ClampedFloatParameter blurSpread = new ClampedFloatParameter(0.6f, 0.2f, 3f);
        [Tooltip("缩放系数")]
        public ClampedIntParameter downSample = new ClampedIntParameter(2, 1, 8);
        [Tooltip("提取较亮区域的阈值")]
        public ClampedFloatParameter luminanceThreshold = new ClampedFloatParameter(0.6f, 0f, 1f);

        public bool IsActive() => _Switch.value;

        public bool IsTileCompatible()
        {
            return false;
        }
    }
}

using System;

namespace UnityEngine.Rendering.Universal
{
    [Serializable, VolumeComponentMenu("Addition-Post-processing/GaussianBlur")]
    public class GaussianBlur : VolumeComponent, IPostProcessComponent
    {
        [Tooltip("开关")]
        public BoolParameter _Switch = new BoolParameter(false);

        [Tooltip("高斯模糊迭代次数")]
        public ClampedFloatParameter iterations = new ClampedFloatParameter(3f, 0f, 4f);
        [Tooltip("模糊范围")]
        public ClampedFloatParameter blurSpread = new ClampedFloatParameter(0.6f, 0.2f, 3f);
        [Tooltip("缩放系数")]
        public ClampedIntParameter downSample = new ClampedIntParameter(2, 1, 8);

        public bool IsActive() => _Switch.value;

        public bool IsTileCompatible()
        {
            return false;
        }
    }
}

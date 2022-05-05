using System;

namespace UnityEngine.Rendering.Universal
{
    [Serializable, VolumeComponentMenu("Addition-Post-processing/MotionBlurWithDepthTexture")]
    public class MotionBlurWithDepthTexture : VolumeComponent, IPostProcessComponent
    {
        [Tooltip("开关")]
        public BoolParameter _Switch = new BoolParameter(false);

        [Tooltip("混合系数")]
        public ClampedFloatParameter blurSize = new ClampedFloatParameter(0.5f, 0.0f, 1.0f);

        public bool IsActive() => _Switch.value;

        public bool IsTileCompatible()
        {
            return false;
        }
    }
}

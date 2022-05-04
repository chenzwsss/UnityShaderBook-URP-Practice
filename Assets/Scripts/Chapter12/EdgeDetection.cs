using System;

namespace UnityEngine.Rendering.Universal
{
    [Serializable, VolumeComponentMenu("Addition-Post-processing/EdgeDetection")]
    public class EdgeDetection : VolumeComponent, IPostProcessComponent
    {
        [Tooltip("开关")]
        public BoolParameter _Switch = new BoolParameter(false);

        [Tooltip("描边控制")]
        public ClampedFloatParameter edgeOnly = new ClampedFloatParameter(1f, 0, 1);
        [Tooltip("描边颜色")]
        public ColorParameter edgeColor = new ColorParameter(Color.black);
        [Tooltip("背景颜色")]
        public ColorParameter backgroundColor = new ColorParameter(Color.white);

        public bool IsActive() => _Switch.value;

        public bool IsTileCompatible()
        {
            return false;
        }
    }
}
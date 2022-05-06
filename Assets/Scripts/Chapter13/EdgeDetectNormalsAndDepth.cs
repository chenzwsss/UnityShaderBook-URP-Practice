using System;

namespace UnityEngine.Rendering.Universal
{
    [Serializable, VolumeComponentMenu("Addition-Post-processing/EdgeDetectNormalsAndDepth")]
    public class EdgeDetectNormalsAndDepth : VolumeComponent, IPostProcessComponent
    {
        [Tooltip("开关")]
        public BoolParameter _Switch = new BoolParameter(false);

        [Tooltip("描边控制")]
        public ClampedFloatParameter edgesOnly = new ClampedFloatParameter(0.0f, 0.0f, 1.0f);
        [Tooltip("描边颜色")]
        public ColorParameter edgeColor = new ColorParameter(Color.black);
        [Tooltip("背景颜色")]
        public ColorParameter backgroundColor = new ColorParameter(Color.white);
        [Tooltip("控制对深度+法线纹理采样时的采样距离, 数值越大, 描边越宽")]
        public FloatParameter sampleDistance = new FloatParameter(1.0f);
        [Tooltip("影响当邻域的深度值相差多少时，会被认为存在一条边界. 如果把灵敏度调得很大, 可能即使深度上的变化很小也会形成一条边")]
        public FloatParameter sensitivityDepth = new FloatParameter(1.0f);
        [Tooltip("影响当邻域的法线值相差多少时，会被认为存在一条边界. 如果把灵敏度调得很大, 可能即使法线值上的变化很小也会形成一条边")]
        public FloatParameter sensitivityNormals = new FloatParameter(1.0f);

        public bool IsActive() => _Switch.value;

        public bool IsTileCompatible()
        {
            return false;
        }
    }
}

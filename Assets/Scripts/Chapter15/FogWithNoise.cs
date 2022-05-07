using System;

namespace UnityEngine.Rendering.Universal
{
    [Serializable, VolumeComponentMenu("Addition-Post-processing/FogWithNoise")]
    public class FogWithNoise : VolumeComponent, IPostProcessComponent
    {
        [Tooltip("开关")]
        public BoolParameter _Switch = new BoolParameter(false);

        [Tooltip("雾的密度")]
        public ClampedFloatParameter fogDensity = new ClampedFloatParameter(1.0f, 0.0f, 3.0f);
        [Tooltip("雾的颜色")]
        public ColorParameter fogColor = new ColorParameter(Color.white);
        [Tooltip("雾的起始高度")]
        public FloatParameter fogStart = new FloatParameter(0.0f);
        [Tooltip("雾的终止高度")]
        public FloatParameter fogEnd = new FloatParameter(2.0f);
        [Tooltip("噪声纹理")]
        public TextureParameter noiseTexture = new TextureParameter(null);
        [Tooltip("X方向速度")]
        public FloatParameter fogXSpeed = new FloatParameter(0.1f);
        [Tooltip("Y方向速度")]
        public FloatParameter fogYSpeed = new FloatParameter(0.1f);
        [Tooltip("雾气控制")]
        public FloatParameter noiseAmount = new FloatParameter(1.0f);

        public bool IsActive() => _Switch.value;

        public bool IsTileCompatible()
        {
            return false;
        }
    }
}

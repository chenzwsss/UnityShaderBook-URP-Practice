#if UNITY_EDITOR
using UnityEditor;
#endif

namespace UnityEngine.Rendering.Universal
{
    public class AdditionalPostProcessDataEditor : ScriptableObject
    {
#if UNITY_EDITOR
        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1812")]

        [MenuItem("Assets/Create/Rendering/Universal Render Pipeline/Additional Post-process Data", priority = CoreUtils.assetCreateMenuPriority3 + 1)]
        static void CreateAdditionalPostProcessData()
        {
            var instance = CreateInstance<AdditionalPostProcessData>();
            AssetDatabase.CreateAsset(instance, string.Format("Assets/{0}.asset", typeof(AdditionalPostProcessData).Name));
            Selection.activeObject = instance;
        }
#endif
    }   
}

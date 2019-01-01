using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEditor;

[ExecuteInEditMode]
[CreateAssetMenu(fileName = "MataRenderPipelineAsset.asset", menuName = "SRPAssets/MataRenderPipeline", order = 1)]
public class MataRenderPipelineAsset : RenderPipelineAsset
{
    public Color clear = Color.green;

#if UNITY_EDITOR
    static void CreateSRP()
    {
        var instance = ScriptableObject.CreateInstance<MataRenderPipelineAsset>();
        if (!AssetDatabase.IsValidFolder("Assets/SRPAssets"))
            AssetDatabase.CreateFolder("Assets", "SRPAssets");
        AssetDatabase.CreateAsset(instance, "Assets/SRPAssets/MataRenderPipelineAsset.asset");
    }
#endif

    protected override IRenderPipeline InternalCreatePipeline()
    {
        return new MataRenderPipeline(this);
    }
}
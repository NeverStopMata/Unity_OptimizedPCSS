using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;



public class MataRenderPipeline : RenderPipeline
{
    private readonly MataRenderPipelineAsset pipelineAsset;

    public MataRenderPipeline(MataRenderPipelineAsset asset)
    {
        pipelineAsset = asset;
    }
    // Start is called before the first frame update
    public override void Render(ScriptableRenderContext context, Camera[] cameras)
    {
        base.Render(context, cameras);
        var clearCmd = new CommandBuffer { name = "Clear(SRP-CommandBuffer)" };
        clearCmd.ClearRenderTarget(true, true, pipelineAsset.clear);
        context.ExecuteCommandBuffer(clearCmd);
        clearCmd.Release();//dispose
        context.Submit();
    }
}

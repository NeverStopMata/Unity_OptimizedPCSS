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
        BeginFrameRendering(cameras);
        foreach (var camera in cameras)
        {
            BeginCameraRendering(camera);

            ScriptableCullingParameters cullingParameters;
            if (!CullResults.GetCullingParameters(camera, out cullingParameters))
                continue;
            CullResults cullResults = new CullResults();
            CullResults.Cull(ref cullingParameters, context, ref cullResults);

            context.SetupCameraProperties(camera);

            var clearCmd = new CommandBuffer { name = "Clear(SRP-CommandBuffer)" };
            clearCmd.ClearRenderTarget(true, false, Color.black);
            context.ExecuteCommandBuffer(clearCmd);
            clearCmd.Release();//dispose

            // Draw opaque objects using BasicLightMode shader pass
            var filterSettings = new FilterRenderersSettings(true);
            var drawSettings = new DrawRendererSettings(camera, new ShaderPassName("ForwardBase"))
            {
                rendererConfiguration = RendererConfiguration.PerObjectLightProbe | RendererConfiguration.PerObjectLightmaps,
            };

            // draw opaque objects
            {

                filterSettings.renderQueueRange = RenderQueueRange.opaque;
                drawSettings.sorting.flags = SortFlags.CommonOpaque;
                context.DrawRenderers(cullResults.visibleRenderers, ref drawSettings, filterSettings);
            }

            // draw skybox
            if (camera.clearFlags == CameraClearFlags.Skybox)
                context.DrawSkybox(camera);

            // draw transparent objects
            {

                filterSettings.renderQueueRange = RenderQueueRange.transparent;
                drawSettings.sorting.flags = SortFlags.CommonTransparent;
                context.DrawRenderers(cullResults.visibleRenderers, ref drawSettings, filterSettings);
            }

            context.Submit();
        }
    }
}

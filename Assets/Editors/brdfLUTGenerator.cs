using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;
public class brdfLUTGenerator : EditorWindow
{
    
    private static float m_angleDelta = 0.0156f;
    private static float m_roughnessDelta = 0.01f;
    private static int m_numBands = 3;
    private static int m_sqrtNumSamples = 500;
    private static Sample[] m_basicSHValueSamples;
    private static Sample[] BasicSHValueSamples
    {
        get
        {
            if (m_basicSHValueSamples != null && m_basicSHValueSamples.Length == m_sqrtNumSamples * m_sqrtNumSamples)
                return m_basicSHValueSamples;
            else
            {
                m_basicSHValueSamples = GenerateBasicSHSamples(m_numBands, m_sqrtNumSamples);
                return m_basicSHValueSamples;
            }
        }
    }
    
    // Start is called before the first frame update
    void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {

    }
    private void OnGUI()
    {
        if(GUILayout.Button("Create"))
        {
            GenerateBRDFLUT();
        }
    }
    [MenuItem("Tools/Create Specular's BRDF LUT")]
    private static void Init()
    {
        brdfLUTGenerator brdfLUTGnrtr = (brdfLUTGenerator)EditorWindow.GetWindow(typeof(brdfLUTGenerator));
        brdfLUTGnrtr.Show();
    }
    private static void GenerateBRDFLUT()
    {
        int angleCnt = (int)(Mathf.PI * 0.5f / m_angleDelta + 0.5f);
        float realAngleDelta = Mathf.PI * 0.5f / (float)angleCnt;
        int roughnessCnt = (int)(1f / m_roughnessDelta + 0.5f);
        float realRoughnessDelta = Mathf.PI / (float)roughnessCnt;
        Texture2D tex1 = new Texture2D(angleCnt + 1, roughnessCnt + 1, TextureFormat.RGBAFloat, false);
        Texture2D tex2 = new Texture2D(angleCnt + 1, roughnessCnt + 1, TextureFormat.RGBAFloat, false);
        Texture2D tex3 = new Texture2D(angleCnt + 1, roughnessCnt + 1, TextureFormat.RFloat, false);
        for (int roughnessIdx = 0; roughnessIdx <= roughnessCnt; roughnessIdx++)
        {
            for (int angleIdx = 0; angleIdx <= angleCnt; angleIdx++)
            {
                float currentAngle = angleIdx * realAngleDelta;
                float currentRoughness = roughnessIdx * realRoughnessDelta;
                float[] BRDFcoeffients = CalculateBRDFCoeffs(currentAngle, currentRoughness, m_numBands, m_sqrtNumSamples);
                tex1.SetPixel(angleIdx, roughnessIdx, new Color(BRDFcoeffients[0], BRDFcoeffients[1], BRDFcoeffients[2], BRDFcoeffients[3]));
                tex2.SetPixel(angleIdx, roughnessIdx, new Color(BRDFcoeffients[4], BRDFcoeffients[5], BRDFcoeffients[6], BRDFcoeffients[7]));
                tex3.SetPixel(angleIdx, roughnessIdx, new Color(BRDFcoeffients[8],0, 0));
            }
        }
        File.WriteAllBytes(Application.dataPath + "/Textures/tex1.exr", tex1.EncodeToEXR(Texture2D.EXRFlags.OutputAsFloat));
        File.WriteAllBytes(Application.dataPath + "/Textures/tex2.exr", tex2.EncodeToEXR(Texture2D.EXRFlags.OutputAsFloat));
        File.WriteAllBytes(Application.dataPath + "/Textures/tex3.exr", tex3.EncodeToEXR(Texture2D.EXRFlags.OutputAsFloat));
    }

    //Assume that the view vector is always in the x-y plane and the viewAngle is the angle between x-axis and view direction.
    private static float[] CalculateBRDFCoeffs(float viewAngle, float roughness, int numBands, int sqrtNumSamples)
    {
        float[] ret = new float[numBands * numBands];
        float finalRoughness = Mathf.Max(roughness * roughness, 0.002f);
        Vector3 N = new Vector3(0, 1, 0);
        Vector3 V = new Vector3(Mathf.Cos(viewAngle), Mathf.Sin(viewAngle), 0);
        float NoV = Vector3.Dot(N, V);
        for(int i = 0;i<ret.Length;i++)
        {
            ret[i] = 0;
            foreach (var basicSample in BasicSHValueSamples)
            {
                Vector3 L = basicSample.sampleDrct;
                Vector3 H = Vector3.Normalize(L + V);
                float NoH = Vector3.Dot(N, H);
                float NoL = Vector3.Dot(N, L);
                float shValue = basicSample.shValues[i];
                float D_V_Dot_product = D_GGX(NoH * NoH, finalRoughness) * Vis_SmithJoint(finalRoughness, NoV, NoL) * NoL;
                ret[i] += shValue * D_V_Dot_product;
            }
        }
        return ret;
    }

    private static float D_GGX(float NoH_squared, float roughness)
    {
        float alpha = roughness * roughness;

        float denom = NoH_squared * (alpha - 1.0f) + 1.0f;
        return alpha / (Mathf.PI * denom * denom);
    }

    // Shlick's approximation of the Fresnel factor.


    private static float Vis_SmithJoint(float roughness, float NoV, float NoL)
    {

        // Approximation of the above formulation (simplify the sqrt, not mathematically correct but close enough)
        float a = roughness;
        float lambdaV = NoL * (NoV * (1 - a) + a);
        float lambdaL = NoV * (NoL * (1 - a) + a);
        return 0.5f / (lambdaV + lambdaL + 1e-5f);
    }

    private static Sample[] GenerateBasicSHSamples(int numBands, int sqrtNumSamples)
    {
        Sample[] basicSHSamples = new Sample[sqrtNumSamples * sqrtNumSamples];
        int index = 0;
        for (int i = 0; i < sqrtNumSamples; ++i)
        {
            for (int j = 0; j < sqrtNumSamples; ++j)
            {
                //Generate the position of this sample in [0, 1)x[0, 1)
                float x = (i + (Random.Range(-0.01f, 0.01f))) / sqrtNumSamples;
                float y = (j + (Random.Range(-0.01f, 0.01f))) / sqrtNumSamples;
                //Convert to spherical polars
                float theta = 2.0f * Mathf.Acos(Mathf.SmoothStep(0,1,Mathf.Sqrt(Mathf.Max(1.0f - x,0f))));
                float phi = 2.0f * Mathf.PI * y;
                //Convert to cartesians
                Vector3 sampleDrct = new Vector3(Mathf.Sin(theta) * Mathf.Cos(phi), Mathf.Sin(theta) * Mathf.Sin(phi), Mathf.Cos(theta));
                basicSHSamples[index] = CalculateBasicSHValue(numBands, sampleDrct);
                ++index;
            }
        }
        return basicSHSamples;
    }
    private static Sample CalculateBasicSHValue(int numBands, Vector3 sampleDrct)//support 3 order sphere harmonic for now.
    {
        Sample ret = new Sample(numBands);
        ret.sampleDrct = sampleDrct;
        float half_rsqrtPi = Mathf.Sqrt(1.0f / Mathf.PI);
        float sqrt3 = Mathf.Sqrt(3);
        float sqrt5 = Mathf.Sqrt(5);
        float sqrt15 = Mathf.Sqrt(15);
        //the order of coeffients is set according to the order of 3-Order SH Coeffients in the Unity Engine.
        ret.shValues[0] = Mathf.Sqrt(1.0f / Mathf.PI) * 0.5f;
        ret.shValues[1] = half_rsqrtPi;
        ret.shValues[2] = half_rsqrtPi * sqrt3 * sampleDrct.y;
        ret.shValues[3] = half_rsqrtPi * sqrt3 * sampleDrct.z;
        ret.shValues[4] = sqrt15 * half_rsqrtPi * sampleDrct.x * sampleDrct.y;
        ret.shValues[5] = sqrt15 * half_rsqrtPi * sampleDrct.y * sampleDrct.z;
        ret.shValues[6] = half_rsqrtPi * sqrt5 * 0.5f * (3 * sampleDrct.z * sampleDrct.z - 1);
        ret.shValues[7] = sqrt15 * half_rsqrtPi * sampleDrct.z * sampleDrct.x;
        ret.shValues[8] = sqrt15 * half_rsqrtPi * 0.5f * (sampleDrct.x * sampleDrct.x - sampleDrct.y * sampleDrct.y);
        return ret;
    }
}

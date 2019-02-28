using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ShadowCaster : MonoBehaviour
{
    public Light m_light;
    // Start is called before the first frame update
    /// <summary>
    /// This function is called when the object becomes enabled and active.
    /// </summary>
    void OnEnable()
    {
        Init();
    }
    void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {

    }
    private void Init()
    {
        m_light = GetComponentInParent<Light>();
        if (m_light != null)
        {
            switch (m_light.type)
            {
                case LightType.Directional:
                    
                    break;
                case LightType.Point:
                    //mata todo
                    break;
                case LightType.Spot:
                    //mata todo
                    break;
                default:
                    break;
            }
        }
    }
}

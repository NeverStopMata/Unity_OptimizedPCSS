using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Sample
{
    public Vector3 sampleDrct;
    public float[] shValues;
    public Sample(int orderNum)
    {
        shValues = new float[orderNum * orderNum];
    }
}

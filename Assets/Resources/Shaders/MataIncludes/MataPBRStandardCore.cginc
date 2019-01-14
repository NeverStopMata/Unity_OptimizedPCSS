#define PI 3.14159265358979
#define EPSILON 0.0000001
#define mata_ColorSpaceDielectricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04) // standard dielectric reflectivity coef at incident angle (= 4%)
// GGX/Towbridge-Reitz normal distribution function.
// Uses Disney's reparametrization of alpha = roughness^2.
inline float D_GGX(float NoH, float roughness)
{
	float alpha   = roughness * roughness;

	float denom = (NoH * NoH) * (alpha - 1.0) + 1.0;
	return alpha / (PI * denom * denom);
}

// Shlick's approximation of the Fresnel factor.
inline float3 F_Schlick( float3 SpecularColor, float VoH )
{
	float Fc = pow( 1 - VoH,5);					// 1 sub, 3 mul
	//return Fc + (1 - Fc) * SpecularColor;		// 1 add, 3 mad
	// Anything less than 2% is physically impossible and is instead considered to be shadowing
	return saturate( 50.0 * SpecularColor.g ) * Fc + (1 - Fc) * SpecularColor;
	
}

inline half Vis_SmithJoint (float Roughness, float NoV, float NoL )
{
    // Approximation of the above formulation (simplify the sqrt, not mathematically correct but close enough)
    half a = Roughness;
    half lambdaV = NoL * (NoV * (1 - a) + a);
    half lambdaL = NoV * (NoL * (1 - a) + a);
    return 0.5f / (lambdaV + lambdaL + 1e-5f);
}

inline float3 Diffuse_Lambert( float3 DiffuseColor)
{
	return DiffuseColor;
}
// [Burley 2012, "Physically-Based Shading at Disney"]
inline float3 Diffuse_Burley( float3 DiffuseColor, float Roughness, float NoV, float NoL, float VoH )
{
	float FD90 = 0.5 + 2 * VoH * VoH * Roughness;
	float FdV = 1 + (FD90 - 1) * Pow5( 1 - NoV );
	float FdL = 1 + (FD90 - 1) * Pow5( 1 - NoL );
	return DiffuseColor * FdV * FdL;
}

inline float3 Diffuse_OrenNayar( float3 DiffuseColor, float Roughness, float NoV, float NoL, float VoH )
{
	float a = Roughness * Roughness;
	float s = a;// / ( 1.29 + 0.5 * a );
	float s2 = s * s;
	float VoL = 2 * VoH * VoH - 1;		// double angle identity
	float Cosri = VoL - NoV * NoL;
	float C1 = 1 - 0.5 * s2 / (s2 + 0.33);
	float C2 = 0.45 * s2 / (s2 + 0.09) * Cosri * ( Cosri >= 0 ? rcp( max( NoL, NoV ) ) : 1 );
	return DiffuseColor / ( C1 + C2 ) * ( 1 + Roughness * 0.5 );
}

inline float3 BoxProjectedCubemapDirct (float3 worldRefl, float3 worldPos, float4 cubemapCenter, float4 boxMin, float4 boxMax)
{

	UNITY_BRANCH
    if (cubemapCenter.w > 0.0)
    {
    	float3 nrdir = normalize(worldRefl);
    	float3 rbmax = (boxMax.xyz - worldPos) / nrdir;
 		float3 rbmin = (boxMin.xyz - worldPos) / nrdir;
    	float3 rbminmax = (nrdir > 0.0f) ? rbmax : rbmin;
    	float fa = min(min(rbminmax.x, rbminmax.y), rbminmax.z);
    	worldPos -= cubemapCenter.xyz;
    	worldRefl = worldPos + nrdir * fa;
	}
    return worldRefl;
}

half3 Mata_GlossyEnvironment (UNITY_ARGS_TEXCUBE(tex), half4 hdr, float3 reflUVW,float roughness)
{
    half perceptualRoughness = roughness /* perceptualRoughness */ ;

// TODO: CAUTION: remap from Morten may work only with offline convolution, see impact with runtime convolution!
// For now disabled
#if 0
    float m = PerceptualRoughnessToRoughness(perceptualRoughness); // m is the real roughness parameter
    const float fEps = 1.192092896e-07F;        // smallest such that 1.0+FLT_EPSILON != 1.0  (+1e-4h is NOT good here. is visibly very wrong)
    float n =  (2.0/max(fEps, m*m))-2.0;        // remap to spec power. See eq. 21 in --> https://dl.dropboxusercontent.com/u/55891920/papers/mm_brdf.pdf

    n /= 4;                                     // remap from n_dot_h formulatino to n_dot_r. See section "Pre-convolved Cube Maps vs Path Tracers" --> https://s3.amazonaws.com/docs.knaldtech.com/knald/1.0.0/lys_power_drops.html

    perceptualRoughness = pow( 2/(n+2), 0.25);      // remap back to square root of real roughness (0.25 include both the sqrt root of the conversion and sqrt for going from roughness to perceptualRoughness)
#else
    // MM: came up with a surprisingly close approximation to what the #if 0'ed out code above does.
    perceptualRoughness = perceptualRoughness*(1.7 - 0.7*perceptualRoughness);
#endif


    half mip = perceptualRoughnessToMipmapLevel(perceptualRoughness);
    half3 R = reflUVW;
    half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(tex, R, mip);

    return DecodeHDR(rgbm, hdr);
}

inline half3 MataGI_IndirectSpecular(float3 originalReflUVW,float3 worldPos, half occlusion, float roughness)
{
    half3 specular;
    float3 reflUVW = BoxProjectedCubemapDirct (originalReflUVW, worldPos, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
    specular = Mata_GlossyEnvironment (UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, reflUVW,roughness);  
    return specular * occlusion;
}

inline half RoughnessToSpecularPower (half Roughness)
{
    half sq = max(1e-4f, Roughness*Roughness);
    half n = (2.0 / sq) - 2.0;                          // https://dl.dropboxusercontent.com/u/55891920/papers/mm_brdf.pdf
    n = max(n, 1e-4f);                                  // prevent possible cases of pow(0,0), which could happen when roughness is 1.0 and NdotH is zero
    return n;
}


inline half OneMinusReflectivityFromMetalness(half metalness)
{
    // We'll need oneMinusReflectivity, so
    //   1-reflectivity = 1-lerp(dielectricSpec, 1, metallic) = lerp(1-dielectricSpec, 0, metallic)
    // store (1-dielectricSpec) in unity_ColorSpaceDielectricSpec.a, then
    //   1-reflectivity = lerp(alpha, 0, metallic) = alpha + metallic*(0 - alpha) =
    //                  = alpha - metallic * alpha
    half oneMinusDielectricSpec = mata_ColorSpaceDielectricSpec.a;
    return oneMinusDielectricSpec - metalness * oneMinusDielectricSpec;
}



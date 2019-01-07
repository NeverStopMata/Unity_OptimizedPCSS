#define PI 3.14159265358979
#define EPSILON 0.0000001
// GGX/Towbridge-Reitz normal distribution function.
// Uses Disney's reparametrization of alpha = roughness^2.
float D_GGX(float NoH, float roughness)
{
	float alpha   = roughness * roughness;
	float alphaSq = alpha * alpha;

	float denom = (NoH * NoH) * (alphaSq - 1.0) + 1.0;
	return alphaSq / (PI * denom * denom);
}

// Shlick's approximation of the Fresnel factor.
float3 F_Schlick( float3 SpecularColor, float VoH )
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
Shader "MataPBR/Opaque"
{
	Properties
	{
		_BaseColor("Color",Color) = (1,1,1,1)
		_Metalness("Metallic",Range(0,1)) = 0
		_Roughness("Roughness",Range(0,1)) = 0
	}
		SubShader
	{
		Tags { "RenderType" = "Opaque" "Queue" = "Geometry" "LightMode" = "ForwardBase" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog

			#include "UnityCG.cginc"
			#include "UnityStandardCore.cginc"
			#include "MataIncludes/MataPBRStandardCore.cginc"
			#include "AutoLight.cginc"
			uniform float4 _BaseColor;
			uniform float _Metalness;
			uniform float _Roughness;
			struct VertexOutput
			{
				float4 pos				: SV_POSITION;
				float2 uv				: TEXCOORD0;
				float3 normalWorld		: TEXCOORD1;
				float3 posWorld			: TEXCOORD2;
			};


			
			VertexOutput vert (appdata_base v)
			{
				VertexOutput o = (VertexOutput)0;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.posWorld = mul(unity_ObjectToWorld,v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.normalWorld = UnityObjectToWorldNormal(v.normal);
				return o;
			}
			
			fixed4 frag (VertexOutput i) : SV_Target
			{

				float3 albedo = _BaseColor.rgb;
				float metalness = _Metalness;
				float roughness = max(_Roughness,0.04);
				float3 V = normalize(_WorldSpaceCameraPos - i.posWorld);
				float3 N = normalize(i.normalWorld);
				float NoV = max(0.0, dot(N, V));
				float3 R = 2.0 * NoV * N - V; //reflection dir of eye direction.
				float3 F0 = lerp((float3)0.04, albedo, metalness);

				float3 directOutput = (float3)0;
				UnityLight mainLight = MainLight();
				float3 L = mainLight.dir;
				float3 lightRadiance = mainLight.color;

				// Half-vector between Li and Lo.
				float3 H = normalize(L + V);
				// Calculate angles between surface normal and various light vectors.
				float NoL = max(0.0, dot(N, L));
				float NoH = max(0.0, dot(N, H));

				// Calculate Fresnel term for direct lighting. 
				float3 F  = F_Schlick(F0, max(0.0, dot(H, V)));
				// Calculate normal distribution for specular BRDF.
				float D = D_GGX(NoH, roughness);
				float Vis =  Vis_SmithJoint(roughness,  NoV,  NoL);
				// Diffuse scattering happens due to light being refracted multiple times by a dielectric medium.
				// Metals on the other hand either reflect or absorb energy, so diffuse contribution is always zero.
				// To be energy conserving we must scale diffuse BRDF contribution based on Fresnel factor & metalness.
				float3 kd = lerp((float3)1.0 - F, (float3)0.0, metalness);
				// Lambert diffuse BRDF.
				// We don't scale by 1/PI for lighting & material units to be more convenient.
				// See: https://seblagarde.wordpress.com/2012/01/08/pi-or-not-to-pi-in-game-lighting-equation/
				float3 diffuseBRDF = kd * albedo;

				// Cook-Torrance specular microfacet BRDF.
				float3 specularBRDF = F * D * Vis;
				// Total contribution for this light.

				//  half3 color =   diffColor * (gi.diffuse + light.color * diffuseTerm)
                //     + specularTerm * light.color * FresnelTerm (specColor, lh)
                //     + surfaceReduction * gi.specular * FresnelLerp (specColor, grazingTerm, nv);
				directOutput += (diffuseBRDF + specularBRDF) * lightRadiance * NoL;
				return OutputForward(half4(directOutput,1), 1);

			}
			ENDCG
		}
	}
}
Shader "MataPBR/Opaque"
{
	Properties
	{
		_BaseColor("Color",Color) = (1,1,1,1)
		_Metalness("Metallic",Range(0,1)) = 0
		_Roughness("Roughness",Range(0,1)) = 0
		_LightTan("lightRadius / lightDiatance",Range(0,0.1)) = 0
	}
	SubShader
	{
		Tags {"RenderType" = "Opaque" "Queue" = "Geometry"}
		LOD 100

		Pass
		{
			Tags { "LightMode"="ForwardBase"}
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog

			#include "UnityCG.cginc"
			#include "UnityStandardCore.cginc"
			#include "MataIncludes/MataPBRStandardCore.cginc"
			#include "AutoLight.cginc"
			uniform float4 _BaseColor;
			uniform float _Metalness;
			uniform float _Roughness;
			uniform float _LightTan;
			struct VertexOutput
			{
				float4 pos				: SV_POSITION;
				float2 uv				: TEXCOORD0;
				float3 normalWorld		: TEXCOORD1;
				float3 posWorld			: TEXCOORD2;
				LIGHTING_COORDS(3, 4)
			};


			
			VertexOutput vert (appdata_base v)
			{
				VertexOutput o = (VertexOutput)0;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.posWorld = mul(unity_ObjectToWorld,v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.normalWorld = UnityObjectToWorldNormal(v.normal);
				TRANSFER_VERTEX_TO_FRAGMENT(o);
				return o;
			}
			
			fixed4 frag (VertexOutput i) : SV_Target
			{
				float3 albedo = _BaseColor.rgb;
				float metalness = _Metalness;
				float perceptualRoughness = _Roughness;
				half smoothness = 1- perceptualRoughness;
				float roughness = max(perceptualRoughness * perceptualRoughness, 0.002);
				float3 V = normalize(_WorldSpaceCameraPos - i.posWorld);
				float3 N = normalize(i.normalWorld);
				float NoV = dot(N, V);
				float3 R = 2.0 * NoV * N - V; //reflection dir of eye direction.
				float3 F0 = lerp(mata_ColorSpaceDielectricSpec.rgb, albedo, metalness);//高光反射率
				float3 diffuseColorForIndirect = lerp(albedo.rgb * unity_ColorSpaceDielectricSpec.a, (float3)0.0, metalness);
				UnityLight mainLight = MainLight();
				float3 L = mainLight.dir;
				float3 lightRadiance = mainLight.color;

				float3 directOutput = (float3)0;

							// Half-vector between Li and Lo.
					float3 H = normalize(L + V);
					// Calculate angles between surface normal and various light vectors.
					float NoL = max(0.0, dot(N, L));
					float NoH = max(0.0, dot(N, H));
					float NoH_squared = NoH * NoH;
					float VoH = dot(V, H);
					float VoL = dot(V, L);
					// Calculate Fresnel term for direct lighting. 
					float3 F  = F_Schlick(F0, max(0.0, dot(H, V)));
					// Calculate normal distribution for specular BRDF.
					float radius_tan = max(0.001,_LightTan - perceptualRoughness *0.25); // light radius is made smaller for rougher materials
					float maxNoH_squared = GetNoHSquared(radius_tan,  NoL,  NoV,  VoL);
					NoH_squared = maxNoH_squared;
					float D = D_GGX(NoH_squared, roughness);
					float Vis =  Vis_SmithJoint(roughness,  NoV,  NoL);
					// Diffuse scattering happens due to light being refracted multiple times by a dielectric medium.
					// Metals on the other hand either reflect or absorb energy, so diffuse contribution is always zero.
					// To be energy conserving we must scale diffuse BRDF contribution based on Fresnel factor & metalness.
					float3 kd = lerp((float3)1.0 - F, (float3)0.0, metalness);
					// Lambert diffuse BRDF.
					// We don't scale by 1/PI for lighting & material units to be more convenient.
					// See: https://seblagarde.wordpress.com/2012/01/08/pi-or-not-to-pi-in-game-lighting-equation/
					float3 diffuseBRDF = Diffuse_Burley( kd * albedo, perceptualRoughness, NoV, NoL, VoH );
					//float3 diffuseBRDF = Diffuse_Lambert(kd * albedo);
					
					// Cook-Torrance specular microfacet BRDF.
					float3 specularBRDF = F * D * Vis;
					// Total contribution for this light.

					//  half3 color =   diffColor * (gi.diffuse + light.color * diffuseTerm)
             		//     + specularTerm * light.color * FresnelTerm (specColor, lh)
                	//     + surfaceReduction * gi.specular * FresnelLerp (specColor, grazingTerm, nv);
					float attenuation = LIGHT_ATTENUATION(i);
					directOutput += (diffuseBRDF + specularBRDF) * lightRadiance * NoL * attenuation;
				

				
				//indirect light evaluate
				UnityIndirect indirect = (UnityIndirect)0;
				indirect.diffuse = ShadeSH9(half4(N,1.0));
				
				half surfaceReduction;
        		surfaceReduction = 2.0 / (roughness*roughness + 1.0) - 1.0;           // fade \in [0.0;1.0]
				half oneMinusReflectivity = OneMinusReflectivityFromMetalness(metalness);
				half grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));
				indirect.specular = MataGI_IndirectSpecular(R,i.posWorld, 1, roughness);
				half3 color  = directOutput
							 + indirect.diffuse * diffuseColorForIndirect
							 + indirect.specular * surfaceReduction * FresnelLerp (F0, grazingTerm, NoV);
				return OutputForward(half4(color,1), 1);

			}
			ENDCG
		}
	}
	FallBack "Diffuse"
}
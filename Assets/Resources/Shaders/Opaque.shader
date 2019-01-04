Shader "Common/Opaque"
{
	Properties
	{
		_Color("Color",Color) = (1,1,1,1)
		_Metallic("Metallic",Range(0,1)) = 0
		_Roughness("Roughness",Range(0,1)) = 0
	}
		SubShader
	{
		Tags { "RenderType" = "Opaque" "Queue" = "Geometry" "LightMode" = "BasicLightMode" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog

			#include "UnityCG.cginc"
			#include "UnityStandardCore.cginc"
			#include "AutoLight.cginc"


			//uniform float _Metallic;
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
				UnityLight mainLight = (UnityLight)0;
				mainLight.color = _LightColor0.rgb;
				mainLight.dir = _WorldSpaceLightPos0.xyz;
				half oneMinusReflectivity;
				half3 specColor;
				half3 diffColor;
				half occlusion;
				half atten = 1;
				occlusion = 1;
				diffColor = DiffuseAndSpecularFromMetallic(_Color, _Metallic, specColor, oneMinusReflectivity);
				FragmentCommonData s = (FragmentCommonData)0;
				s.diffColor = diffColor;
				s.specColor = specColor;
				s.oneMinusReflectivity = oneMinusReflectivity;
				s.smoothness = 1 - _Roughness;
				s.normalWorld = i.normalWorld;
				s.eyeVec = normalize(i.posWorld - _WorldSpaceCameraPos); 
				s.posWorld = i.posWorld;

				

				UnityGI gi = FragmentGI(s, occlusion, 0, atten, mainLight, true);
				half4 c = UNITY_BRDF_PBS(s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, s.eyeVec, gi.light, gi.indirect);
				UNITY_APPLY_FOG(i.fogCoord, c.rgb);
				
				return OutputForward(c, 1);
			}
			ENDCG
		}
	}
}
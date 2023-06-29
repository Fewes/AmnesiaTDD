////////////////////////////////////////////////////////
// Deferred G-Buffer Light - Fragment Shader
//
// A shader applied to the accumlation buffer, using the
// G-buffer targets as input.
//
// Postion retrival from depth:
// The position gvFarPlanePos is at the far plane and the far x,y and z postions can be thought of as a "trinagle"
// The wanted position can also be thought of as a "triangle" with the same ratio as the far one. The ratio is expressed as
// the stored depth value since it is wanted_pos.z/farplane.
//	
////////////////////////////////////////////////////////
#version 120
#extension GL_ARB_texture_rectangle : enable

@include helper_float_packing.glsl

//--------------------------------------------------------------


///////////////////////////////
// Shadow helper functions

float ShadowOffsetLookup(sampler2DShadow aShadowMap, vec4 avLocation, vec2 avOffset)
{
	return shadow2DProj(aShadowMap, vec4(avLocation.xy + avOffset, avLocation.z, avLocation.w) ).x;
}


//--------------------------------------------------------------

#define USE_PBR
#define USE_PHYSICAL_LIGHT_ATTEN

////////////////////
//Varying varaibles
varying vec3 gvFarPlanePos;	//The pixel postion projected to the far plane

@ifdef UseBatching
	varying vec3 gvLightPosition;		
	varying vec4 gvLightColor;
	varying float gfLightRadius;
@endif

////////////////////
//Uniform varaibles
@ifdef UseBatching
	//Do nothing
@else
	uniform vec3 avLightPos;
	uniform float afInvLightRadius;
	uniform vec4 avLightColor;
@endif

//Division is done with farplane
@ifdef DivideInFrag
	uniform float afNegFarPlane;
@endif

//Spotlight specfics
@ifdef LightType_Spot
	@ifdef UseGobo || UseShadowMap
		uniform mat4 a_mtxSpotViewProj;
	@endif
		
	@ifdef UseGobo
	@else
		uniform float afOneMinusCosHalfSpotFOV;
		uniform vec3 avLightForward;
	@endif
	
	@ifdef UseShadowMap
		@ifdef ShadowMapQuality_Low
		@else
			uniform vec2 avShadowMapOffsetMul;
		@endif
	@endif
//Point specfics
@else
	@ifdef UseGobo
		uniform mat4 a_mtxInvViewRotation;
	@endif
@endif

////////////////////
//Textures
uniform sampler2DRect  aDiffuseMap;
@define sampler_aDiffuseMap 0

uniform sampler2DRect  aNormalMap;
@define sampler_aNormalMap 1

uniform sampler2DRect  aDepthMap;
@define sampler_aDepthMap 2

@ifdef RenderTargets_4
	uniform sampler2DRect  aExtraMap;
	@define sampler_aExtraMap 3
@endif

uniform sampler1D  aAttenuationMap;
@define sampler_aAttenuationMap 4

////////////////////////////
//Additional textures

//Spot light
@ifdef LightType_Spot
	@ifdef UseGobo
		uniform sampler2D aGoboMap;
		@define sampler_aGoboMap 5
	@else
		uniform sampler1D aSpotFalloffMap;
		@define sampler_aSpotFalloffMap 5
	@endif
//Point light
@else
	uniform samplerCube aGoboMap;
	@define sampler_aGoboMap 5
@endif

//Shadow map
@ifdef UseShadowMap
	uniform sampler2DShadow aShadowMap;
	@define sampler_aShadowMap 6
	
	@ifdef ShadowMapQuality_Low
	@else
		uniform sampler2D aShadowOffsetMap;
		@define sampler_aShadowOffsetMap 7
	@endif
@endif

//--------------------------------------------------------------

#define PI 3.14159265359
#define saturate(o) clamp(o, 0.0, 1.0)

float pow5(float x) {
    float x2 = x * x;
    return x2 * x2 * x;
}

float D_GGX(float linearRoughness, float NoH, const vec3 h) {
    // Walter et al. 2007, "Microfacet Models for Refraction through Rough Surfaces"
    float oneMinusNoHSquared = 1.0 - NoH * NoH;
    float a = NoH * linearRoughness;
    float k = linearRoughness / (oneMinusNoHSquared + a * a);
    float d = k * k * (1.0 / PI);
    return d;
}

float V_SmithGGXCorrelated(float linearRoughness, float NoV, float NoL) {
    // Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"
    float a2 = linearRoughness * linearRoughness;
    float GGXV = NoL * sqrt((NoV - a2 * NoV) * NoV + a2);
    float GGXL = NoV * sqrt((NoL - a2 * NoL) * NoL + a2);
    return 0.5 / (GGXV + GGXL);
}

vec3 F_Schlick(const vec3 f0, float VoH) {
    // Schlick 1994, "An Inexpensive BRDF Model for Physically-Based Rendering"
    return f0 + (vec3(1.0) - f0) * pow5(1.0 - VoH);
}

float F_Schlick(float f0, float f90, float VoH) {
    return f0 + (f90 - f0) * pow5(1.0 - VoH);
}

float Fd_Burley(float linearRoughness, float NoV, float NoL, float LoH) {
    // Burley 2012, "Physically-Based Shading at Disney"
    float f90 = 0.5 + 2.0 * linearRoughness * LoH * LoH;
    float lightScatter = F_Schlick(1.0, f90, NoL);
    float viewScatter  = F_Schlick(1.0, f90, NoV);
    return lightScatter * viewScatter * (1.0 / PI);
}

float Fd_Lambert() {
    return 1.0 / PI;
}

//--------------------------------------------------------------

///////////////////////////////
// Main program
void main()
{
	/////////////////////////////////
	//Get values from samplers
	vec2 vMapCoords = gl_FragCoord.xy;
	vec4 vColorVal =  texture2DRect(aDiffuseMap, vMapCoords);
	vec4 vNormalVal = texture2DRect(aNormalMap, vMapCoords);
	vec4 vDepthVal =  texture2DRect(aDepthMap, vMapCoords);
	@ifdef RenderTargets_4
		vec4 vExtraVal = texture2DRect(aExtraMap, vMapCoords);
	@endif
		
	/////////////////////////////////
	//When using batching, set up variables differently
	@ifdef UseBatching
		vec3 avLightPos = gvLightPosition;
		float afInvLightRadius = gfLightRadius;
		vec4 avLightColor = gvLightColor;
	@endif
	
	/////////////////////////////////
	// Get postion
	
	//32 bit has packed depth
	@ifdef Deferred_32bit
		float fDepth = UnpackVec3ToFloat(vDepthVal.xyz);
			
		@ifdef DivideInFrag
			vec3 vPos;
			vPos.xy = (gvFarPlanePos.xy / gvFarPlanePos.z);
			vPos.z =  afNegFarPlane;
			vPos.xyz *= fDepth; 
		@else
			vec3 vPos = gvFarPlanePos * fDepth; 
		@endif
	//64 bit stores postion directly
	@elseif Deferred_64bit
		vec3 vPos = vDepthVal.xyz;	
	@endif
	
	
	/////////////////////////////////
	// Light direction and attenuation
	vec3 vLightDir = (avLightPos - vPos) * afInvLightRadius;
	float fLightDistNorm = clamp(1.0 - sqrt(dot(vLightDir,vLightDir)), 0.0, 1.0);
	float fAttenuation =  texture1D(aAttenuationMap,dot(vLightDir,vLightDir)).x;
	float fLightDist = length(vLightDir);
	vLightDir = normalize( vLightDir );

	float lightDist = length(avLightPos - vPos);
	// fAttenuation = mix(fAttenuation, 1.0 / (lightDist*lightDist + 1.0), 0.99);
	// fAttenuation *= 1.0 / (lightDist*lightDist + 0.1);

	// Non-physical falloff
	float fFalloff1 = fLightDistNorm*fLightDistNorm;
	// Physical falloff (with limit)
	float fFalloff2 = 1.0 / (lightDist*lightDist + 0.1) * sqrt(fLightDistNorm);
	// fAttenuation *= 1.0 / (lightDist + 0.1);

#ifdef USE_PHYSICAL_LIGHT_ATTEN
	// fAttenuation = mix(fAttenuation, fFalloff1 + fFalloff2, 0.999);
	fAttenuation = mix(fAttenuation, fAttenuation + fFalloff2, 0.999);
	// fAttenuation += fFalloff2;
#endif
	
	//////////////////////////////
	//Spot attentuation / gobo
	@ifdef LightType_Spot
		@ifdef UseGobo
			vec4 vProjectedUv = a_mtxSpotViewProj * vec4(vPos,1.0);
			vec3 vGoboVal = texture2DProj(aGoboMap, vProjectedUv).xyz;
		@else
			float fOneMinusCos = 1.0 - dot( vLightDir,  avLightForward);
			fAttenuation *= texture1D(aSpotFalloffMap, fOneMinusCos / afOneMinusCosHalfSpotFOV).x;
		@endif
	//////////////////////////////
	//Point gobo
	@else
		@ifdef UseGobo
			vec4 vWorldLightDir = a_mtxInvViewRotation * vec4(vLightDir,1.0);
			vec3 vGoboVal = textureCube(aGoboMap, vWorldLightDir.xyz).xyz;
		@endif
	@endif
	
	/////////////////////////////////
	//Unpack normal and normalize (if needed)
	@ifdef Deferred_32bit
		vec3 vNormal = vNormalVal.xyz*2.0 - 1.0;
	@elseif Deferred_64bit
		vec3 vNormal = vNormalVal.xyz;
	@endif
	
	@ifdef UseSpecular
		vNormal = normalize(vNormal);
	@endif

	// vColorVal.xyz = mix(vColorVal.xyz, vec3(1.0), 0.999);
	
	/////////////////////////////////
	//Calculate diffuse color
	float fLDotN = max( dot( vLightDir, vNormal.xyz), 0.0);
	vec3 vDiffuse = vColorVal.xyz * avLightColor.xyz * fLDotN;
	
	/////////////////////////////////
	//Calculate specular color
	@ifdef UseSpecular
		
		@ifdef RenderTargets_4
			float fSpecIntensity = vExtraVal.x;
			float fSpecPower = vExtraVal.y;
		@else
			float fSpecIntensity = vNormalVal.w;
			float fSpecPower = vDepthVal.w;
		@endif
		
		vec3 vHalfVec = normalize(vLightDir + normalize(-vPos));
		float fSpecPower2 = exp2(fSpecPower * 10.0) + 1.0;//Range 0 - 1024
		vec3 vSpecular = vec3(avLightColor.w * fSpecIntensity *  pow( clamp( dot( vHalfVec, vNormal.xyz), 0.0, 1.0),fSpecPower2 ) );
		vSpecular *= avLightColor.xyz;
	@endif

#ifdef USE_PBR
	vec3 v = normalize(-vPos);
	vec3 n = vNormal;
	vec3 l = vLightDir;
	vec3 h = normalize(v + l);
	vec3 r = normalize(reflect(-v, n));

	float NoV = abs(dot(n, v)) + 1e-5;
	float NoL = saturate(dot(n, l));
	float NoH = saturate(dot(n, h));
	float LoH = saturate(dot(l, h));

	vec3 baseColor = vColorVal.xyz;
	float roughness = 0.7;
	float metallic = 0.0;

	@ifdef UseSpecular
	roughness = 1.0 - fSpecPower;
	metallic = fSpecIntensity;
	@endif

	float linearRoughness = roughness * roughness;
	vec3 diffuseColor = (1.0 - metallic) * baseColor.rgb;
	vec3 f0 = 0.04 * (1.0 - metallic) + baseColor.rgb * metallic;

	// specular BRDF
	float D = D_GGX(linearRoughness, NoH, h);
	float V = V_SmithGGXCorrelated(linearRoughness, NoV, NoL);
	vec3  F = F_Schlick(f0, LoH);
	vec3 Fr = (D * V) * F;

	// diffuse BRDF
	vec3 Fd = diffuseColor * Fd_Burley(linearRoughness, NoV, NoL, LoH);

	vDiffuse = mix(vDiffuse, Fd * avLightColor.xyz * NoL * PI, 0.999);
	@ifdef UseSpecular
	// vSpecular = mix(vSpecular, Fr * NoL * PI * avLightColor.w * fSpecIntensity * avLightColor.xyz, 0.999);
	vSpecular = mix(vSpecular, Fr * NoL * PI * avLightColor.xyz * NoL, 0.999);
	@endif
#endif
	
	/////////////////////////////////
	// Caclulate shadow (if any)
	
	@ifdef UseShadowMap && LightType_Spot
		
		@ifdef UseGobo
		@else
			vec4 vProjectedUv = a_mtxSpotViewProj * vec4(vPos,1.0);
		@endif
			
		////////////////////////
		// No Smoothing
		@ifdef ShadowMapQuality_Low
		
			fAttenuation *= shadow2DProj(aShadowMap, vProjectedUv).x;
					
		///////////////////////
		// Smoothing
		@else	
			//Set up variables
			float fShadowSum = 0;
			float fJitterZ =0;
			vec2 vScreenJitterCoord = gl_FragCoord.xy * $ShadowJitterLookupMul;
			
			vScreenJitterCoord.y = fract(vScreenJitterCoord.y);	 //Make sure the coord is in 0 - 1 range
			vScreenJitterCoord.y *= 1.0 / $ShadowJitterSamplesDiv2;	 //Access only first texture piece
						
				
			////////////////
			// Shader Model 3, Dynamic Branching available
			@ifdef ShaderModel_4
				////////////////
				// Cheap pre-test
				//  Note1: division must occur when getting samples else gfx card gets angry.)
				//  Note2: It _must_ be division! doing sample * 1/8 will fail!!
				for(int i=0; i<2.0; i++)
				{
					vec2 vJitterLookupCoord = vec2(vScreenJitterCoord.x, vScreenJitterCoord.y + fJitterZ);
					
					vec4 vOffset = texture2D(aShadowOffsetMap, vJitterLookupCoord) *2.0-1.0;
									
					fShadowSum += ShadowOffsetLookup(aShadowMap, vProjectedUv, vec2(vOffset.xy) * avShadowMapOffsetMul ) / 4.0;
					fShadowSum += ShadowOffsetLookup(aShadowMap, vProjectedUv, vec2(vOffset.zw) * avShadowMapOffsetMul ) / 4.0;
								
					fJitterZ += 1.0 / $ShadowJitterSamplesDiv2;
				}
				
				////////////////
				// Check if in penumbra
				if( (fShadowSum-1.0) * fShadowSum * fLDotN != 0)
				{ 	
					//Multiply, so the X presamples only affect their part (X/all_samples) of samples taken.
					fShadowSum *= 4.0 / $ShadowJitterSamples; 
								
					////////////////
					// Fullscale filtering
					for(int i=0; i<$ShadowJitterSamplesDiv2-2.0; i++)
					{
						vec2 vJitterLookupCoord = vec2(vScreenJitterCoord.x, vScreenJitterCoord.y + fJitterZ); //Not that coords are 0-1!
					
						vec4 vOffset = texture2D(aShadowOffsetMap, vJitterLookupCoord) *2.0 - 1.0;
															
						fShadowSum += ShadowOffsetLookup(aShadowMap, vProjectedUv, vec2(vOffset.xy) * avShadowMapOffsetMul ) / $ShadowJitterSamples;
						fShadowSum += ShadowOffsetLookup(aShadowMap, vProjectedUv, vec2(vOffset.zw) * avShadowMapOffsetMul ) / $ShadowJitterSamples;
						
						fJitterZ += 1.0 / $ShadowJitterSamplesDiv2;
					}
					
					//vDiffuse.xyz = vec3(0,0,1);
				}
				/*else
				{
					if(fShadowSum>0.5) 	vDiffuse.xyz = vec3(1,0,0);	
					else		 	vDiffuse.xyz = vec3(0,1,0);
					
					//fAttenuation *= fShadowSum;	
				}*/
			/////////////////////
			// No Dynamic Branching
			@else
				for(int i=0; i<$ShadowJitterSamplesDiv2; i++)
				{
					vec2 vJitterLookupCoord = vec2(vScreenJitterCoord.x, vScreenJitterCoord.y + fJitterZ);
					
					vec4 vOffset = texture2D(aShadowOffsetMap, vJitterLookupCoord) *2.0 - 1.0;
					
					fShadowSum += ShadowOffsetLookup(aShadowMap, vProjectedUv, vec2(vOffset.xy) * avShadowMapOffsetMul );
					fShadowSum += ShadowOffsetLookup(aShadowMap, vProjectedUv, vec2(vOffset.zw) * avShadowMapOffsetMul );
								
					fJitterZ += 1.0 / $ShadowJitterSamplesDiv2;
				}
				
				fShadowSum /= $ShadowJitterSamples;
			@endif
			
			
			/////////////////////
			// Add shadow sum to attenuation
			fAttenuation *= fShadowSum;
		@endif
		
	
	@endif
		
	/////////////////////////////////
	//Final color
	@ifdef UseSpecular
		@ifdef UseGobo
			gl_FragColor.xyz = (vSpecular + vDiffuse) * vGoboVal * fAttenuation;
		@else
			gl_FragColor.xyz = (vSpecular + vDiffuse) * fAttenuation;
		@endif
	@else
		@ifdef UseGobo
			gl_FragColor.xyz = vDiffuse * vGoboVal * fAttenuation;
		@else
			gl_FragColor.xyz = vDiffuse * fAttenuation;
		@endif
	@endif

	@ifdef UseSpecular
	// gl_FragColor.xyz = mix(gl_FragColor.xyz, vec3(roughness), 0.999);
	@endif
	
	////////////////////////////////
	//Debug output
	
	//gl_FragColor.xyz = vNormalVal.xyz;
	//gl_FragColor.xyz = vec3( clamp( dot( vLightDir, vNormalVal.xyz), 0.0 ,1.0) );
	//gl_FragColor.xyz =  (vPos/10) *0.5 +0.5;
	//gl_FragColor.xyz =  vec3(fAttenuation) * avLightColor.xyz;
	//gl_FragColor.xyz =  vLightDir*0.5+0.5;
	//gl_FragColor.xyz =  vDiffuse.xyz;
	//gl_FragColor.xyz =  vec3(fLDotN);
	//gl_FragColor.xyz =  vColorVal.xyz;// * avLightColor.xyz * fAttenuation * clamp( dot( vLightDir, vNormalVal.xyz), 0.0, 1.0);
	//gl_FragColor.xyz =    vec3(vExtraVal.x);
	//gl_FragColor.xyz =  avLightColor.xyz * fAttenuation * min( dot( vLightDir, vNormalVal.xyz), 1.0);
	//gl_FragColor.xyz = vec3(1);
	//gl_FragColor.xyz = gl_FragColor.xyz = vNormalVal.xyz;
	//gl_FragColor.xyz = vec3(fDepth);
}


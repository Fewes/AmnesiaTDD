////////////////////////////////////////////////////////
// Deferred Light Box - Fragment Shader
//
// Fragment program to draw a light box. 
////////////////////////////////////////////////////////
#version 120
#extension GL_ARB_texture_rectangle : enable

////////////////////
//Textures
uniform sampler2DRect  aDiffuseMap;
@define sampler_aDiffuseMap 0

@ifdef UseSSAO
	uniform sampler2DRect  aSSAOMap;
	@define sampler_aSSAOMap 5
@endif

////////////////////
//Uniform varaibles
uniform vec4 avLightColor;

void main()
{
	vec2 vMapCoords = gl_FragCoord.xy;
	vec4 vColorVal =  texture2DRect(aDiffuseMap, vMapCoords);
	
	@ifdef UseSSAO
		vColorVal *= texture2DRect(aSSAOMap, vMapCoords * 0.5);	//SSAO should be half the size of the screen.
	@endif
	
	//Multiply with light color and AO (w).
	vec3 vLightColor = avLightColor.xyz;
	vLightColor = pow(vLightColor, vec3(2.2));
	gl_FragColor.xyz = vColorVal.xyz * vLightColor;
}
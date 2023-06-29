////////////////////////////////////////////////////////
// Deferred Decal - Fragment Shader
//
// A decal shader
////////////////////////////////////////////////////////
#version 120

@include core.glsl

varying vec4 gvColor;

uniform sampler2D aDiffuseMap;
@define sampler_aDiffuseMap 0

void main()
{
	////////////////////
	//Diffuse 
	vec4 vFinalColor = texture2D(aDiffuseMap, gl_TexCoord[0].xy);

	// Linearize
	vFinalColor.xyz = SRGBToLinear(vFinalColor.xyz);
		
	gl_FragColor = vFinalColor * gvColor;
}
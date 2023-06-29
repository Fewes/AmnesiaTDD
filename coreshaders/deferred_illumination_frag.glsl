////////////////////////////////////////////////////////
// Deferred Illumination - Fragment Shader
//
// Used in a sepperate pass to render illuminating parts of a material.
////////////////////////////////////////////////////////
#version 120

@include core.glsl

uniform sampler2D aDiffuse;
@define sampler_aDiffuse 0

uniform float afColorMul;

void main()
{
	vec4 vDiffuseColor = texture2D(aDiffuse, gl_TexCoord[0].xy);
	// Linearize
	vDiffuseColor.xyz = SRGBToLinear(vDiffuseColor.xyz);
	gl_FragColor = vDiffuseColor * afColorMul;
}
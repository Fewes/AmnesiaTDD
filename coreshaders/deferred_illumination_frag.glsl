////////////////////////////////////////////////////////
// Deferred Illumination - Fragment Shader
//
// Used in a sepperate pass to render illuminating parts of a material.
////////////////////////////////////////////////////////
#version 120

uniform sampler2D aDiffuse;
@define sampler_aDiffuse 0

uniform float afColorMul;

void main()
{
	vec4 vDiffuseColor = texture2D(aDiffuse, gl_TexCoord[0].xy);
	// Linearize
	vDiffuseColor.xyz = pow(vDiffuseColor.xyz, vec3(2.2));
	gl_FragColor = vDiffuseColor * afColorMul;
}
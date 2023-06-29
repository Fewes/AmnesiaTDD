////////////////////////////////////////////////////////
// PostEffect Bloom Blur - Fragment Shader
//
// Blur effect for the bloom post effect
////////////////////////////////////////////////////////
#version 120

#extension GL_ARB_texture_rectangle : enable

@include core.glsl

uniform sampler2DRect blurMap;
@define sampler_blurMap 0

uniform sampler2DRect diffuseMap;
@define sampler_diffuseMap 1

uniform vec3 avRgbToIntensity;

void main()
{
	vec4 vBlurColor = texture2DRect(blurMap, gl_TexCoord[0].xy);
	vec4 vDiffuseColor = texture2DRect(diffuseMap, gl_TexCoord[1].xy);
	
#ifdef USE_BETTER_BLOOM
	vDiffuseColor.xyz = LinearToSRGB(vDiffuseColor.xyz);
#else
	vBlurColor *= vBlurColor * dot(vBlurColor.xyz, avRgbToIntensity);
#endif
	
	gl_FragColor = vDiffuseColor + vBlurColor * 0.5;
}
////////////////////////////////////////////////////////
// Deferred Decal - Fragment Shader
//
// A decal shader
////////////////////////////////////////////////////////
#version 120

varying vec4 gvColor;

uniform sampler2D aDiffuseMap;
@define sampler_aDiffuseMap 0

void main()
{
	////////////////////
	//Diffuse 
	vec4 vFinalColor = texture2D(aDiffuseMap, gl_TexCoord[0].xy);

	// Linearize
	vFinalColor.xyz = pow(vFinalColor.xyz, vec3(2.2));
		
	gl_FragColor = vFinalColor * gvColor;
}
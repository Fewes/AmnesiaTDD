#version 120

uniform float afFarPlane;

@ifdef Deferred_32bit
varying vec3 gvFarPlanePos;
@endif

void main()
{	
	gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
	gl_TexCoord[0] = gl_MultiTexCoord0;

@ifdef Deferred_32bit
	gvFarPlanePos = vec3(gl_Vertex.xy, afFarPlane);
@endif
}
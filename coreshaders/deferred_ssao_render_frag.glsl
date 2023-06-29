#version 120

#extension GL_ARB_texture_rectangle : enable

uniform float afFarPlane;

uniform float afScatterLengthMul;
uniform vec2 avScatterLengthLimits;
uniform float afDepthDiffMul;
uniform float afSkipEdgeLimit;

uniform vec2 avScreenSize;

uniform sampler2DRect depthMap;
@define sampler_depthMap 0

uniform sampler2D scatterDisk;
@define sampler_scatterDisk 1

void main()
{
	///////////////
	// This is the core depth that we compare to
	float fCoreDepth = texture2DRect(depthMap, gl_TexCoord[0].xy).x;
	
	
	//Have a max limit on the length, or else there will be major slowdowns when many objects are upfront.
	//Multiply with height (y) since width varies with aspect!
	//Also added a min length to make stuff darker at a distance to avoid flickering.
	float fScatterLength = clamp(afScatterLengthMul / (fCoreDepth * afFarPlane), avScatterLengthLimits.x, avScatterLengthLimits.y) * avScreenSize.y;	
	float fScatterDiskZ =0.0;
	
	vec2 vScreenScatterCoord = (gl_FragCoord.xy) * 1.0 / 4.0; //4 = size of scatter texture, and this is to get a 1-1 pixel-texture usage.
	
	vScreenScatterCoord.y = fract(vScreenScatterCoord.y);	 //Make sure the coord is in 0 - 1 range
	vScreenScatterCoord.y *= 1.0 / $SampleNumDiv2;		//Access only first texture piece
		
	///////////////////////////////////////////
	// Depth enhance
	float fOccSum =0.0;
	float fFarPlaneMulDepthDiffMul = afFarPlane * afDepthDiffMul;
	
	//////////////////////////////////////////
	// Go through the samples, 4 at a time!
	for(int i=0; i<$SampleNumDiv2 / 2; i++)
	{
		//Get the scatter coordinates (used to get the randomized postion for each sampling)
		vec2 vScatterLookupCoord1 = vec2(vScreenScatterCoord.x, vScreenScatterCoord.y + fScatterDiskZ*4.0);
					
		vec4 vOffset1 = (texture2D(scatterDisk, vScatterLookupCoord1) *2.0 - 1.0)  * fScatterLength;
		
		//Look up the depth at the random samples. Notice that x-z and y-w are each others opposites! (important for extra polation below!)
		vec4 vDepth = vec4(	texture2DRect(depthMap, gl_TexCoord[0].xy + vOffset1.xy).x,
					texture2DRect(depthMap, gl_TexCoord[0].xy + vOffset1.zw).x,
					texture2DRect(depthMap, gl_TexCoord[0].xy - vOffset1.xy).x,
					texture2DRect(depthMap, gl_TexCoord[0].xy - vOffset1.zw).x);
		
		//The z difference in world coords multplied with DepthDiffMul
		vec4 vDiff = (fCoreDepth - vDepth) * fFarPlaneMulDepthDiffMul;
		
		//This this test to remove halos. If a certain limit is reached, then the negative value of the opposite difference is used. 
		//This acts as an extrapolation "behind" the blocking geometry)
		vec4 vDiffSwap = -vDiff.zwxy;
		/*if(vDiff.x > afSkipEdgeLimit) vDiff.x = vDiffSwap.x;
		if(vDiff.y > afSkipEdgeLimit) vDiff.y = vDiffSwap.y;
		if(vDiff.z > afSkipEdgeLimit) vDiff.z = vDiffSwap.z;
		if(vDiff.w > afSkipEdgeLimit) vDiff.w = vDiffSwap.w;*/
		
		//Invert the difference (so positive means uncovered) and then give unocvered values a slight advantage	
		//Also sett a max negative value (limits how much covered areas can affect.
		vDiff = max(vec4(1) - vDiff, -0.7);
		
		//Caclculate the occulsion value, (the squaring makes sharper dark areas)
		vec4 vOcc = min(vDiff*vDiff, 1.0f);
		
		fOccSum += dot(vOcc,vec4(1.0));
		
		//Change the z coord for random coord look up (so new values are used on next iteration)
		fScatterDiskZ += (1.0 / $SampleNumDiv2) * 2.0;
	}
	
	float fOcc = fOccSum / (2.0 * $SampleNumDiv2);

	// fOcc = 1.0;
	
	gl_FragColor.xyz = vec3(fOcc * fOcc);
	
	//gl_FragColor.x = smoothstep(0.0, 1.0, fOccDepth);
	//gl_FragColor.x = mod(vScreenScatterCoord.x, 1.0);
	
	
	//gl_FragColor.x = pow(fOcc, 1.25);
	//gl_FragColor.x = smoothstep(0.0, 1.0, fOcc);	//Use this to darken dark spots and make very brigth stuff white. This removes artefacts without making the scene too bright.
	
	//vec3 vScatterLookupCoord = vec3(vScreenScatterCoord, 0);
	//gl_FragColor.x = texture3D(scatterDisk, vScatterLookupCoord).x;
}


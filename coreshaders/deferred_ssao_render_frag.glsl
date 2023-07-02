#version 120

#extension GL_ARB_texture_rectangle : enable

@include core.glsl
@include helper_float_packing.glsl

#define HBAO

uniform float afFarPlane;

uniform float afScatterLengthMul;
uniform vec2 avScatterLengthLimits;
uniform float afDepthDiffMul;
uniform float afSkipEdgeLimit;

uniform vec2 avScreenSize;

uniform mat4 a_mtxProjectionMatrix;

uniform sampler2DRect depthMap;
@define sampler_depthMap 0

uniform sampler2D scatterDisk;
@define sampler_scatterDisk 1

uniform sampler2DRect normalMap;
@define sampler_normalMap 2

#define KERNEL_SIZE 32
const vec4 vKernel[KERNEL_SIZE] = vec4 [KERNEL_SIZE]
(
	vec4(0.02360764, 0.02359158, 0.09449926, 0.1002197),
	vec4(0.0586644, -0.04291701, 0.07152649, 0.1019775),
	vec4(0.07749471, 0.000931708, 0.07157171, 0.1054932),
	vec4(-0.06572654, 0.06817373, 0.0574596, 0.1107666),
	vec4(0.05330245, 0.06378264, 0.0834683, 0.1177979),
	vec4(-0.1003323, -0.02339484, 0.07355519, 0.1265869),
	vec4(-0.08672819, 0.01107684, 0.1056466, 0.1371338),
	vec4(-0.09844045, 0.06818817, 0.08939635, 0.1494385),
	vec4(0.1171083, -0.05571328, 0.09957026, 0.163501),
	vec4(0.1510558, 0.09602866, 0.01080567, 0.1793213),
	vec4(-0.02286901, -0.07381397, 0.1811019, 0.1968994),
	vec4(-0.1457049, -0.1503319, 0.05411221, 0.2162354),
	vec4(-0.1545612, -0.1782097, 0.02602344, 0.2373291),
	vec4(-0.1195175, -0.05745659, 0.2238488, 0.2601807),
	vec4(0.2268126, 0.1721995, 0.00295983, 0.28479),
	vec4(-0.2212895, -0.1309346, 0.175231, 0.3111572),
	vec4(0.1931441, -0.2775297, 0.02801873, 0.3392822),
	vec4(0.006593584, -0.05896979, 0.3643651, 0.369165),
	vec4(0.157461, 0.2434498, 0.2767371, 0.4008057),
	vec4(0.3331839, 0.1457904, 0.2372064, 0.4342041),
	vec4(-0.04430655, -0.2203072, 0.4120689, 0.4693604),
	vec4(0.1050849, -0.4563914, 0.1922962, 0.5062744),
	vec4(0.2971731, 0.2872533, 0.3551622, 0.5449463),
	vec4(0.3167179, -0.3578346, 0.3380964, 0.585376),
	vec4(-0.3410299, 0.4028328, 0.3394999, 0.6275635),
	vec4(-0.3532384, 0.1149644, 0.5594013, 0.6715088),
	vec4(0.5421939, 0.2432786, 0.4015397, 0.7172119),
	vec4(-0.04724785, -0.7628989, 0.02185103, 0.7646729),
	vec4(0.7133331, 0.1443858, 0.3643189, 0.8138916),
	vec4(0.4594036, 0.725035, 0.1061579, 0.8648682),
	vec4(0.841275, -0.04018507, 0.364192, 0.9176025),
	vec4(-0.5012578, -0.4265468, 0.7153787, 0.9720947)
);

// const float fOffset[5] = float[5]( -2.5, -0.75, 0.0, 0.75,  2.5);

@ifdef Deferred_32bit
varying vec3 gvFarPlanePos;
@endif

vec3 GetPosition(vec2 vMapCoords)
{
	vec4 vDepthVal = texture2DRect(depthMap, vMapCoords);

	//32 bit has packed depth
@ifdef Deferred_32bit
	float fDepth = UnpackVec3ToFloat(vDepthVal.xyz);
	vec3 vPos = gvFarPlanePos * fDepth; 
	//64 bit stores postion directly
@elseif Deferred_64bit
	vec3 vPos = vDepthVal.xyz;
@endif

	return vPos;
}

mat2x2 RotationMatrix2D(float a)
{
	float s = sin(a);
	float c = cos(a);
	return mat2x2(c, -s, s, c);
}

void main()
{
	///////////////
	// This is the core depth that we compare to
	float fCoreDepth = texture2DRect(depthMap, gl_TexCoord[0].xy).x;

	vec4 vNormalVal = texture2DRect(normalMap, gl_TexCoord[0].xy * 2.0);
@ifdef Deferred_32bit
	vec3 vNormal = vNormalVal.xyz * 2.0 - 1.0;
@elseif Deferred_64bit
	vec3 vNormal = vNormalVal.xyz;
@endif
	
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
	float fFarPlaneMulDepthDiffMul = afFarPlane * afDepthDiffMul;
	
#ifdef HBAO
	float fJitter = GetBayer(gl_FragCoord.xy);

	vNormal.z *= -1; // TODO: Makes it correct. Why???
	vec3 vBinormal = vec3(0, 1, 0);
	vec3 vTangent = normalize(cross(vBinormal, vNormal));

	vTangent.xy = RotationMatrix2D(fJitter * 2 * PI) * vTangent.xy;

	vBinormal = normalize(cross(vNormal, vTangent)); // TODO: Can probably skip normalize
	mat3x3 TBN = mat3x3(vTangent, vBinormal, vNormal);
	// mat3x3 TBN = mat3x3(vNormal, vBinormal, vTangent);

	vec3 vPos = GetPosition(gl_FragCoord.xy);

	const float fRadiusScale = 1.0;
	const float fSurfaceBias = 0.05;
	const float fSlopeBias = 0.1;
	const float fThickness = 3.0;
	const float fExponent = 4.0;

	// float fRadius = 1.0 * fJitter; // Fixed radius
	float fRadius = fRadiusScale * clamp(vPos.z * 0.2, 0.05, 1.0); // Scaled radius to get some details on lantern + distant geo
	float fOcc = 0.0;
	float fWeightSum = 0.0;
	for (int i = 0; i < KERNEL_SIZE; i++)
	{
		vec4 vDir = vKernel[i];
		vDir.xyz = normalize(mix(vDir.xyz, vec3(0, 0, 1), fSlopeBias)) * vDir.w;
		vDir.xyz = TBN * vDir.xyz;
		// vDir.xyz *= sign(dot(vDir.xyz, vNormal));
		// vec3 localPos = vPos + vDir.xyz * fRadius;
		vec3 localPos = vPos + vDir.xyz * fRadius + vNormal * fRadius * fSurfaceBias;
		// vec2 localCoords = localPos.xy;
		// vec3 bufferPos = GetPosition(localCoords);
		// vec4 clipPos = gl_ProjectionMatrix * vec4(bufferPos, 1.0);

		vec4 clipPos = a_mtxProjectionMatrix * vec4(localPos * vec3(1, 1,-1), 1.0); // Note flipped z
		vec2 uv = clipPos.xy / clipPos.w * 0.5 + vec2(0.5);
		vec2 localCoord = uv * avScreenSize;
		vec3 localBufferPos = GetPosition(localCoord);
		float fZDiff = localPos.z - localBufferPos.z;
		// if (localPos.z > vPos.z + 0.1 && )
		// if (fZDiff > 0.1 && fZDiff < 0.2)
		

		float fWeight = GetVignette(uv);

		fWeight *= smoothstep(fRadius * fThickness, 0.0, fZDiff);

		if (fZDiff > fRadius * fThickness)
		{
			fWeight = 0.0;
		}

		if (fZDiff > 0)
		{
			// fAttenuation = 0.0;
			fOcc += fWeight;
		}

		fWeightSum += fWeight;
	}
	fOcc = pow(1.0 - fOcc / fWeightSum, fExponent);
#else
	float fOccSum = 0.0;
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
	fOcc *= fOcc;
#endif

	// fOcc = 1.0;
	
	gl_FragColor.xyz = vec3(fOcc);
	
	//gl_FragColor.x = smoothstep(0.0, 1.0, fOccDepth);
	//gl_FragColor.x = mod(vScreenScatterCoord.x, 1.0);
	
	
	//gl_FragColor.x = pow(fOcc, 1.25);
	//gl_FragColor.x = smoothstep(0.0, 1.0, fOcc);	//Use this to darken dark spots and make very brigth stuff white. This removes artefacts without making the scene too bright.
	
	//vec3 vScatterLookupCoord = vec3(vScreenScatterCoord, 0);
	//gl_FragColor.x = texture3D(scatterDisk, vScatterLookupCoord).x;
}


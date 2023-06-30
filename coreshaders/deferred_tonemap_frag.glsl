#version 120

#extension GL_ARB_texture_rectangle : enable

@include core.glsl

uniform sampler2DRect diffuseMap;
@define sampler_diffuseMap 0

// Code from https://www.shadertoy.com/view/lslGzl

vec3 ApplyGamma(vec3 vColor, float gamma)
{
	return pow(vColor, vec3(1.0 / gamma));
}

vec3 SimpleReinhardToneMapping(vec3 color)
{
	float exposure = 1.5;
	return color * exposure / (1.0 + color / exposure);
}

vec3 LumaBasedReinhardToneMapping(vec3 color)
{
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	float toneMappedLuma = luma / (1. + luma);
	return color * toneMappedLuma / luma;
}

vec3 WhitePreservingLumaBasedReinhardToneMapping(vec3 color)
{
	float white = 2.;
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	float toneMappedLuma = luma * (1. + luma / (white*white)) / (1. + luma);
	return color * toneMappedLuma / luma;
}

vec3 RomBinDaHouseToneMapping(vec3 color)
{
    return exp( -1.0 / ( 2.72*color + 0.15 ) );
}

vec3 ACESToneMapping(vec3 x)
{
    // Narkowicz 2015, "ACES Filmic Tone Mapping Curve"
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return x = (x * (a * x + b)) / (x * (c * x + d) + e);
}

vec3 Uncharted2ToneMapping(vec3 color)
{
	float A = 0.15;
	float B = 0.50;
	float C = 0.10;
	float D = 0.20;
	float E = 0.02;
	float F = 0.30;
	float W = 11.2;
	float exposure = 2.;
	color *= exposure;
	color = ((color * (A * color + C * B) + D * E) / (color * (A * color + B) + D * F)) - E / F;
	float white = ((W * (A * W + C * B) + D * E) / (W * (A * W + B) + D * F)) - E / F;
	return color /= white;
}

void main()
{
	vec3 vColor = texture2DRect(diffuseMap, gl_TexCoord[0].xy).xyz;

#ifdef USE_TONEMAPPING
	// vColor = SimpleReinhardToneMapping(vColor);
	// vColor = LumaBasedReinhardToneMapping(vColor);
	// vColor = WhitePreservingLumaBasedReinhardToneMapping(vColor);
	// vColor = RomBinDaHouseToneMapping(vColor);
	vColor = Uncharted2ToneMapping(vColor);
	// vColor = ACESToneMapping(vColor);
#endif

#ifdef USE_LINEAR_RENDERING
	vColor = LinearToSRGB(vColor);
#endif

	// Dither gets rid of ugly color banding
	vColor = max(vec3(0.0), vColor + (Dither(gl_TexCoord[0].xy) - 0.5) / 255.0);
	
	gl_FragColor.xyz = vColor;
	gl_FragColor.w = 1.0;
}
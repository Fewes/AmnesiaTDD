#define PI 3.14159265359
#define saturate(o) clamp(o, 0.0, 1.0)

#define USE_LINEAR_RENDERING
#define USE_PBR
#define USE_PHYSICAL_LIGHT_ATTEN
#define USE_TONEMAPPING
#define USE_BETTER_BLOOM

float pow5(float x)
{
    float x2 = x * x;
    return x2 * x2 * x;
}

// https://chilliant.blogspot.com/2012/08/srgb-approximations-for-hlsl.html?m=1
vec3 SRGBToLinear(vec3 color)
{
#ifdef USE_LINEAR_RENDERING
	return color * (color * (color * 0.305306011 + vec3(0.682171111)) + vec3(0.012522878));
#else
	return color;
#endif
}
vec3 LinearToSRGB(vec3 color)
{
#ifdef USE_LINEAR_RENDERING
	return saturate(1.055 * pow(abs(color), vec3(0.416666667)) - vec3(0.055));
#else
	return color;
#endif
}

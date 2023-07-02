#define PI 3.14159265359
#define saturate(o) clamp(o, 0.0, 1.0)

#define USE_LINEAR_RENDERING
#define USE_PBR
#define USE_PHYSICAL_LIGHT_ATTEN
#define USE_TONEMAPPING
#define USE_BETTER_BLOOM
#define USE_CONTACT_SHADOWS
#define USE_PHYSICAL_FOG

float sq(float x)
{
	return x * x;
}
float pow5(float x)
{
    float x2 = x * x;
    return x2 * x2 * x;
}

float GetVignette(vec2 uv)
{
	vec2 vig = uv * (1.0 - uv.yx);
	return saturate(vig.x * vig.y * 15.0);
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

vec3 Dither(vec2 vScreenPos)
{
	vec3 vDither = vec3(dot(vec2(131.0, 312.0), vScreenPos.xy));
	vDither.rgb = fract(vDither.rgb / vec3(103.0, 71.0, 97.0)) - vec3(0.5, 0.5, 0.5);
	return vDither.rgb;
}

mat4 bayerIndex = mat4(
    vec4(00.0/16.0, 12.0/16.0, 03.0/16.0, 15.0/16.0),
    vec4(08.0/16.0, 04.0/16.0, 11.0/16.0, 07.0/16.0),
    vec4(02.0/16.0, 14.0/16.0, 01.0/16.0, 13.0/16.0),
    vec4(10.0/16.0, 06.0/16.0, 09.0/16.0, 05.0/16.0));

float GetBayer(vec2 vScreenPos)
{
	// int x = int(vScreenPos.x);
	// int y = int(vScreenPos.y);
	int x = int(mod(vScreenPos.x, 4));
	int y = int(mod(vScreenPos.y, 4));
	return bayerIndex[x][y];
}
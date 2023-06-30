// Based on https://www.shadertoy.com/view/XlKSDR

float D_GGX(float linearRoughness, float NoH, const vec3 h)
{
    // Walter et al. 2007, "Microfacet Models for Refraction through Rough Surfaces"
    float oneMinusNoHSquared = 1.0 - NoH * NoH;
    float a = NoH * linearRoughness;
    float k = linearRoughness / (oneMinusNoHSquared + a * a);
    float d = k * k * (1.0 / PI);
    return d;
}

float V_SmithGGXCorrelated(float linearRoughness, float NoV, float NoL)
{
    // Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"
    float a2 = linearRoughness * linearRoughness;
    float GGXV = NoL * sqrt((NoV - a2 * NoV) * NoV + a2);
    float GGXL = NoV * sqrt((NoL - a2 * NoL) * NoL + a2);
    return saturate(0.5 / (GGXV + GGXL));
}

vec3 F_Schlick(const vec3 f0, float VoH)
{
    // Schlick 1994, "An Inexpensive BRDF Model for Physically-Based Rendering"
    return f0 + (vec3(1.0) - f0) * pow5(1.0 - VoH);
}

float F_Schlick(float f0, float f90, float VoH)
{
    return f0 + (f90 - f0) * pow5(1.0 - VoH);
}

float Fd_Burley(float linearRoughness, float NoV, float NoL, float LoH)
{
    // Burley 2012, "Physically-Based Shading at Disney"
    float f90 = 0.5 + 2.0 * linearRoughness * LoH * LoH;
    float lightScatter = F_Schlick(1.0, f90, NoL);
    float viewScatter  = F_Schlick(1.0, f90, NoV);
    return lightScatter * viewScatter * (1.0 / PI);
}

float Fd_Lambert()
{
    return 1.0 / PI;
}

//--------------------------------------------------------------

vec2 PrefilteredDFG_Karis(float roughness, float NoV)
{
    // Karis 2014, "Physically Based Material on Mobile"
    const vec4 c0 = vec4(-1.0, -0.0275, -0.572,  0.022);
    const vec4 c1 = vec4( 1.0,  0.0425,  1.040, -0.040);

    vec4 r = roughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;

    return vec2(-1.04, 1.04) * a004 + r.zw;
}

//--------------------------------------------------------------

void GetPBR(vec3 baseColor, float roughness, float metallic, vec3 v, vec3 n, vec3 l, out vec3 Fr, out vec3 Fd)
{
	vec3 h = normalize(v + l);
	vec3 r = normalize(reflect(-v, n));

	float NoV = abs(dot(n, v)) + 1e-5;
	float NoL = saturate(dot(n, l));
	float NoH = saturate(dot(n, h));
	float LoH = saturate(dot(l, h));

	vec3 diffuseColor = (1.0 - metallic) * baseColor.rgb;
	vec3 f0 = 0.04 * (1.0 - metallic) + baseColor.rgb * metallic;
	float linearRoughness = roughness * roughness;

	// specular BRDF
	float D = D_GGX(linearRoughness, NoH, h);
	float V = V_SmithGGXCorrelated(linearRoughness, NoV, NoL);
	vec3 F = F_Schlick(f0, LoH);
	Fr = (D * V) * F * NoL * PI;

	// diffuse BRDF
	Fd = diffuseColor * Fd_Burley(linearRoughness, NoV, NoL, LoH) * NoL * PI;
}

void GetPBRIndirect(vec3 baseColor, float roughness, float metallic, vec3 v, vec3 n, out vec3 Fr)
{
	float NoV = abs(dot(n, v)) + 1e-5;

	vec3 diffuseColor = (1.0 - metallic) * baseColor.rgb;
	vec3 f0 = 0.04 * (1.0 - metallic) + baseColor.rgb * metallic;

	// indirect contribution
	vec2 dfg = PrefilteredDFG_Karis(roughness, NoV);
	Fr = f0 * dfg.x + dfg.y;
}
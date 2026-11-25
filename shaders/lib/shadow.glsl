// =====================================================================
//  Sombras: distorsion del mapa + muestreo PCF ligero
// =====================================================================

#define SHADOW_DISTORT 0.85

vec3 distortShadow(vec3 p) {
    float d = length(p.xy);
    float f = d * SHADOW_DISTORT + (1.0 - SHADOW_DISTORT);
    return vec3(p.xy / f, p.z * 0.25);
}

// Desplazamiento a lo largo de la normal para evitar acne (en bloques)
float shadowNormalOffset(float dist) {
    float texel = 2.0 * shadowDistance / float(shadowMapResolution);
    return texel * (1.2 + 2.5 * clamp(dist / shadowDistance, 0.0, 1.0));
}

#ifdef SHADOW_SAMPLER
uniform sampler2DShadow shadowtex0;

const vec2 shadowOffsets8[8] = vec2[8](
    vec2(-0.7071,  0.7071), vec2( 0.0000, -0.8750), vec2( 0.5303,  0.5303), vec2(-0.6250,  0.0000),
    vec2( 0.3536, -0.3536), vec2( 0.0000,  0.3750), vec2(-0.1768, -0.1768), vec2( 0.1250,  0.0000)
);

// shadowClip: posicion en clip space de la sombra SIN distorsionar.
// Devuelve 1 = iluminado. Fuera del mapa devuelve -1.
float sampleShadow(vec3 shadowClip, float dither) {
    vec3 p = distortShadow(shadowClip) * 0.5 + 0.5;
    if (p.x <= 0.0 || p.x >= 1.0 || p.y <= 0.0 || p.y >= 1.0 || p.z >= 1.0) return -1.0;
    p.z -= 0.00008;

    #if SHADOW_FILTER == 0
        return texture(shadowtex0, p);
    #else
        float r = 1.4 / float(shadowMapResolution);
        float a = dither * 6.2831853;
        mat2 rot = mat2(cos(a), sin(a), -sin(a), cos(a));
        float s = 0.0;
        #if SHADOW_FILTER == 1
            for (int i = 0; i < 4; i++) {
                s += texture(shadowtex0, vec3(p.xy + rot * shadowOffsets8[i * 2] * r * 1.5, p.z));
            }
            return s * 0.25;
        #else
            for (int i = 0; i < 8; i++) {
                s += texture(shadowtex0, vec3(p.xy + rot * shadowOffsets8[i] * r * 2.0, p.z));
            }
            return s * 0.125;
        #endif
    #endif
}
#endif

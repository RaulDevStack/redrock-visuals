// =====================================================================
//  Viento en plantas y olas del agua
// =====================================================================

// Ids de block.properties
#define ID_WATER     10001
#define ID_PLANT     10002   // se mueven los vertices superiores
#define ID_LEAVES    10003   // se mueven todos, poco
#define ID_TALL_TOP  10005   // mitad superior de plantas altas: se mueven todos
#define ID_EMISSIVE  10010
#define ID_LAVA      10011

vec3 wavePlant(vec3 wp, float strength) {
    float t = frameTimeCounter * WAVING_SPEED;
    float gust = 0.55 + 0.45 * sin(t * 0.33 + wp.x * 0.04 + wp.z * 0.03);
    float wx = sin(t * 1.7 + wp.x * 0.6 + wp.z * 0.4) * 0.6 + sin(t * 2.9 + wp.x * 1.3 - wp.z * 0.9) * 0.4;
    float wz = sin(t * 2.1 + wp.z * 0.7 - wp.x * 0.3) * 0.5 + sin(t * 3.3 + wp.z * 1.1) * 0.3;
    return vec3(wx, 0.0, wz * 0.6) * 0.08 * strength * WAVING_STRENGTH * gust * (1.0 + rainStrength);
}

// Vertice en la superficie de un fluido: altura no entera (la base esta en y entera).
// Asi se mueven a la vez la cara superior y el borde de las caras laterales: sin huecos.
bool isFluidSurfaceVertex(vec3 wp) {
    float fy = fract(wp.y + 0.001);
    return fy > 0.05;
}

// Olas reales del agua (geometria). Siempre <= 0: nunca sube por encima de la
// altura vanilla, asi no atraviesa bloques ni deja rendijas.
float waterVertexWave(vec3 wp) {
    float t = frameTimeCounter * WAVE_SPEED;
    vec2 d1 = normalize(vec2(1.0, 0.35));
    vec2 d2 = normalize(vec2(-0.45, 1.0));
    float w = sin(dot(d1, wp.xz) * 0.38 + t * 1.10) * 0.6
            + sin(dot(d2, wp.xz) * 0.61 + t * 1.55) * 0.4;
    return (w - 1.0) * 0.5 * 0.10 * WAVING_WATER_HEIGHT * (1.0 + rainStrength * 0.5);
}

// Lava: ondulacion lenta y espesa
float lavaVertexWave(vec3 wp) {
    float t = frameTimeCounter * 0.6;
    float w = sin(wp.x * 0.55 + wp.z * 0.25 + t) * 0.5
            + sin(wp.z * 0.70 - wp.x * 0.30 + t * 0.7) * 0.5;
    return (w - 1.0) * 0.5 * 0.08 * WAVING_LAVA_HEIGHT;
}

// Desplazamiento de vertices del terreno segun el tipo de bloque
vec3 terrainWave(int id, vec3 wp, bool topVertex) {
    #ifdef WAVING_PLANTS
        if ((id == ID_PLANT && topVertex) || id == ID_TALL_TOP) return wavePlant(wp, 1.0);
    #endif
    #ifdef WAVING_LEAVES
        if (id == ID_LEAVES) return wavePlant(wp, 0.40);
    #endif
    #ifdef WAVING_LAVA
        if (id == ID_LAVA && isFluidSurfaceVertex(wp)) return vec3(0.0, lavaVertexWave(wp), 0.0);
    #endif
    #ifdef WAVING_WATER
        if (id == ID_WATER && isFluidSurfaceVertex(wp)) return vec3(0.0, waterVertexWave(wp), 0.0);
    #endif
    return vec3(0.0);
}

#ifdef WATER_WAVES_FUNC
// Suma de ondas direccionales suaves (derivada analitica) + un poco de ruido fino.
// Devuelve la pendiente (dh/dx, dh/dz).
vec2 waveSlope(vec2 p, float t, vec2 dir, float freq, float amp, float speed) {
    dir = normalize(dir);
    float ph = dot(dir, p) * freq + t * speed;
    return dir * (cos(ph) * amp * freq);
}

vec3 waterNormal(vec3 wp, float dist) {
    float t = frameTimeCounter * WAVE_SPEED;
    vec2 p = wp.xz;
    vec2 s = vec2(0.0);
    s += waveSlope(p, t, vec2( 1.0,  0.35), 0.38, 0.060, 1.10);
    s += waveSlope(p, t, vec2(-0.45, 1.0),  0.61, 0.035, 1.55);
    s += waveSlope(p, t, vec2( 0.80, -0.6), 1.07, 0.018, 2.10);
    s += waveSlope(p, t, vec2(-1.0, -0.25), 1.73, 0.009, 2.70);
    // ruido fino para romper la regularidad
    const float e = 0.15;
    vec2 q = p * 0.45 + vec2(t * 0.12, -t * 0.09);
    float n0 = noise2D(q);
    s += vec2(noise2D(q + vec2(e, 0.0)) - n0, noise2D(q + vec2(0.0, e)) - n0) / e * 0.025;
    // menos detalle a lo lejos: evita el parpadeo y el aspecto granulado
    s *= WAVE_STRENGTH * (1.0 + rainStrength * 0.5) / (1.0 + dist * 0.025);
    return normalize(vec3(-s.x, 1.0, -s.y));
}
#endif

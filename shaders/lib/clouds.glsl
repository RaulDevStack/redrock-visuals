// =====================================================================
//  Nubes volumetricas: cumulos dispersos de desierto (requiere noise.glsl)
// =====================================================================

vec2 cloudWind() {
    float t = frameTimeCounter * CLOUD_SPEED;
    return vec2(t * 2.0, t * 0.7);
}

float cloudCoverage() {
    return mix(CLOUD_COVERAGE, 0.85, rainStrength);
}

// Forma 2D a gran escala (3 lecturas de textura)
float cloudShape(vec2 xz) {
    vec2 q = (xz + cloudWind()) * 0.0028;
    float n = noise2D(q) * 0.60;
    n += noise2D(q * 2.63 + vec2(13.1, 7.7)) * 0.28;
    n += noise2D(q * 6.91 + vec2(3.3, 21.4)) * 0.12;
    return n;
}

float cloudBase(float shape) {
    float cov = cloudCoverage();
    return clamp((shape - (1.0 - cov)) / max(cov, 0.05), 0.0, 1.0);
}

float cloudDensity(vec3 p, bool detail) {
    float h = (p.y - CLOUD_HEIGHT) / CLOUD_THICKNESS;
    if (h <= 0.0 || h >= 1.0) return 0.0;
    float base = cloudBase(cloudShape(p.xz));
    if (base <= 0.0) return 0.0;
    // base plana, cima redondeada
    float profile = smoothstep(0.0, 0.10, h) * (1.0 - smoothstep(0.30, 1.0, h));
    float d = base - (1.0 - profile) * 0.75;
    if (detail && d > 0.0) {
        vec2 w = cloudWind();
        d -= noise3D(p * 0.045 + vec3(w.x, 0.0, w.y) * 0.03) * 0.30;
    }
    return max(d, 0.0) * 0.09 * CLOUD_DENSITY;
}

float phaseHG(float mu, float g) {
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * PI * pow(1.0 + g2 - 2.0 * g * mu, 1.5));
}

// Sombra de nubes sobre el terreno (2D, barata)
float getCloudShadow(vec3 worldPos, vec3 lightDir) {
    float mid = CLOUD_HEIGHT + CLOUD_THICKNESS * 0.4;
    vec3 p = worldPos + lightDir * ((mid - worldPos.y) / max(lightDir.y, 0.05));
    float b = cloudBase(cloudShape(p.xz));
    return 1.0 - smoothstep(0.0, 0.6, b) * 0.70;
}

// Devuelve rgb = luz dispersada, a = transmitancia
vec4 renderClouds(vec3 camPos, vec3 dir, float sceneDist, float dither,
                  vec3 lightDir, vec3 lightCol, vec3 ambient, vec3 horizonCol) {
    float bottom = CLOUD_HEIGHT;
    float top = CLOUD_HEIGHT + CLOUD_THICKNESS;
    float dy = abs(dir.y) < 1e-4 ? 1e-4 : dir.y;
    float tb = (bottom - camPos.y) / dy;
    float tt = (top - camPos.y) / dy;
    float t0 = max(min(tb, tt), 0.0);
    float t1 = min(max(tb, tt), sceneDist);
    if (t1 <= t0 || t0 > CLOUD_FAR) return vec4(0.0, 0.0, 0.0, 1.0);
    t1 = min(t1, t0 + 900.0);

    float stepLen = (t1 - t0) / float(CLOUD_STEPS);
    float t = t0 + stepLen * dither;
    float mu = dot(dir, lightDir);
    float phase = mix(phaseHG(mu, 0.65), phaseHG(mu, -0.25), 0.35) * 4.0 * PI;

    vec3 scatter = vec3(0.0);
    float T = 1.0;
    for (int i = 0; i < CLOUD_STEPS; i++) {
        vec3 p = camPos + dir * t;
        float d = cloudDensity(p, true);
        if (d > 0.0005) {
            float od = 0.0;
            float ls = 10.0;
            for (int j = 0; j < CLOUD_LIGHT_STEPS; j++) {
                od += cloudDensity(p + lightDir * ls * (float(j) + 0.5) * 1.6, false) * ls * 1.6;
                ls *= 1.8;
            }
            float beer = exp(-od * 0.9);
            float powder = 1.0 - exp(-d * 40.0);
            float hf = (p.y - bottom) / CLOUD_THICKNESS;
            vec3 L = lightCol * beer * phase * mix(0.6, 1.0, powder) + ambient * (0.45 + 0.75 * hf);
            float st = exp(-d * stepLen);
            scatter += L * T * (1.0 - st);
            T *= st;
            if (T < 0.03) break;
        }
        t += stepLen;
    }

    // perspectiva aerea: las nubes lejanas se funden con el horizonte
    float far01 = smoothstep(0.0, CLOUD_FAR, t0);
    scatter = mix(scatter, horizonCol * (1.0 - T), far01 * 0.65);
    float fade = 1.0 - smoothstep(CLOUD_FAR * 0.55, CLOUD_FAR, t0);
    return vec4(scatter * fade, mix(1.0, T, fade));
}

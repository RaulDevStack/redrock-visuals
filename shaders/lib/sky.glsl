// =====================================================================
//  Cielo, colores del sol/luna y luz ambiente (tonos western calidos)
// =====================================================================

vec3 getSunDir()   { return normalize(mat3(gbufferModelViewInverse) * sunPosition); }
vec3 getLightDir() { return normalize(mat3(gbufferModelViewInverse) * shadowLightPosition); }

float sunsetFactor(float h) {
    float s = clamp(1.0 - abs(h - 0.03) * 4.5, 0.0, 1.0);
    return s * s;
}

// Color del disco solar segun la altura del sol: naranja polvoriento al amanecer, blanco calido a mediodia
vec3 sunColorRaw(float h) {
    vec3 low  = vec3(1.00, 0.36, 0.08);
    vec3 mid  = vec3(1.00, 0.60, 0.28);
    vec3 high = vec3(1.00, 0.84, 0.62);
    vec3 c = mix(low, mid, smoothstep(0.0, 0.15, h));
    c = mix(c, high, smoothstep(0.15, 0.5, h));
    return c;
}

// Luz direccional principal (sol de dia, luna de noche)
vec3 getLightColor(float h) {
    vec3 sun  = sunColorRaw(h) * smoothstep(-0.02, 0.10, h) * 2.1 * SUN_INTENSITY;
    vec3 moon = vec3(0.50, 0.62, 0.95) * 0.14 * smoothstep(0.0, 0.12, -h) * MOON_INTENSITY;
    return (sun + moon) * (1.0 - rainStrength * 0.85);
}

vec3 getAmbientColor(float h) {
    float day = smoothstep(-0.10, 0.25, h);
    float set = sunsetFactor(h);
    vec3 dayC   = vec3(0.50, 0.50, 0.54);
    vec3 setC   = vec3(0.52, 0.34, 0.24);
    vec3 nightC = vec3(0.035, 0.045, 0.075);
    vec3 c = mix(nightC, dayC, day);
    c = mix(c, setC, set * 0.6);
    float l = luminance(c);
    c = mix(c, vec3(l) * vec3(0.9, 0.95, 1.0) * 0.8, rainStrength * 0.7);
    return c * 0.55 * AMBIENT_INTENSITY;
}

// Cielo procedural barato. dir y sunDir en espacio mundo, normalizados.
vec3 getSkyColor(vec3 dir, vec3 sunDir, bool drawSun) {
    float h = sunDir.y;
    float day = smoothstep(-0.08, 0.25, h);
    float set = sunsetFactor(h);

    vec3 zenDay   = vec3(0.16, 0.30, 0.62);
    vec3 horDay   = vec3(0.70, 0.60, 0.46);  // horizonte polvoriento y calido
    vec3 zenSet   = vec3(0.16, 0.18, 0.36);
    vec3 horSet   = vec3(1.00, 0.42, 0.14);
    vec3 zenNight = vec3(0.004, 0.007, 0.018);
    vec3 horNight = vec3(0.018, 0.022, 0.036);

    vec3 zen = mix(zenNight, zenDay, day);
    zen = mix(zen, zenSet, set * 0.75);
    vec3 hor = mix(horNight, horDay, day);
    hor = mix(hor, horSet, set);

    float y = dir.y;
    float g = 1.0 - clamp(y, 0.0, 1.0);
    g = g * g * g;
    vec3 sky = mix(zen, hor, g);
    // por debajo del horizonte: bruma de suelo algo mas oscura
    sky = mix(sky, hor * 0.6, clamp(-y * 2.5, 0.0, 1.0));

    float cosS = dot(dir, sunDir);
    float glow = pow(max(cosS, 0.0), 5.0);
    sky += horSet * glow * (set * 1.1 + 0.10 * day) * (0.35 + 0.65 * g);
    float mie = pow(max(cosS, 0.0), 48.0);
    sky += sunColorRaw(h) * mie * 0.7 * smoothstep(-0.05, 0.05, h);

    // halo lunar sutil
    float cosM = dot(dir, -sunDir);
    sky += vec3(0.05, 0.06, 0.09) * pow(max(cosM, 0.0), 24.0) * (1.0 - day);

    float l = luminance(sky);
    sky = mix(sky, vec3(l) * vec3(0.85, 0.88, 0.92) * 0.75, rainStrength * 0.85);

    if (drawSun) {
        float disk = smoothstep(0.99955, 0.99978, cosS);
        sky += sunColorRaw(h) * disk * 40.0 * (1.0 - rainStrength) * smoothstep(-0.03, 0.02, h);
    }
    return sky;
}

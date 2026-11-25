// =====================================================================
//  Niebla volumetrica: polvo/bruma de suelo con rayos de luz (god rays)
//  Requiere noise.glsl, clouds.glsl (phaseHG) y, con sombras, shadow.glsl
// =====================================================================

float fogTimeMultiplier(vec3 sunDir) {
    float m = 1.0;
    #ifdef MORNING_FOG
        float fromSunrise = min(sunAngle, 1.0 - sunAngle);
        m += 2.2 * (1.0 - smoothstep(0.0, 0.07, fromSunrise));
    #endif
    m *= mix(1.0, 0.75, smoothstep(0.0, -0.2, sunDir.y));   // algo menos de noche
    m *= 1.0 + rainStrength * 3.0;
    return m;
}

float fogDensityAt(vec3 worldPos) {
    float h = worldPos.y - FOG_HEIGHT;
    float d = exp(-max(h, 0.0) / FOG_FALLOFF);
    #ifdef DUST_NOISE
        float t = frameTimeCounter;
        d *= 0.45 + 1.1 * noise3D(worldPos * 0.035 + vec3(t * 0.35, t * 0.05, t * 0.12));
    #endif
    return d;
}

// dir: direccion de la vista (mundo), dist: distancia a la geometria.
vec4 volumetricFog(vec3 dir, float dist, float dither, vec3 sunDir, vec3 lightDir, vec3 lightCol, vec3 ambient) {
    float maxDist = min(min(dist, far), 192.0);
    float eyeSky = eyeSkyLight();
    float densMul = 0.0022 * FOG_DENSITY * fogTimeMultiplier(sunDir);

    // polvo del desierto: tine la luz dispersada de ocre
    const vec3 DUST = vec3(1.00, 0.80, 0.58);
    float mu = dot(dir, lightDir);
    float phase = mix(phaseHG(mu, 0.70), 1.0 / (4.0 * PI), 0.45) * 4.0 * PI;
    vec3 sunScatter = lightCol * DUST * phase * 0.45 * VL_INTENSITY;
    vec3 ambScatter = ambient * DUST * 0.30 * mix(0.15, 1.0, eyeSky);

    #if defined SHADOWS && defined SHADOW_SAMPLER
        vec3 sOrigin = (shadowProjection * (shadowModelView * vec4(0.0, 0.0, 0.0, 1.0))).xyz;
        vec3 sDir    = (shadowProjection * (shadowModelView * vec4(dir, 0.0))).xyz;
    #endif

    vec3 scatter = vec3(0.0);
    float T = 1.0;
    float prevT = 0.0;
    for (int i = 0; i < VL_STEPS; i++) {
        float f = (float(i) + dither) / float(VL_STEPS);
        float t = maxDist * f * f;
        float dt = t - prevT;
        prevT = t;

        vec3 wp = cameraPosition + dir * t;
        float d = fogDensityAt(wp) * densMul;

        float sh = eyeSky;   // fuera del mapa de sombras: aproximacion por luz del cielo
        #if defined SHADOWS && defined SHADOW_SAMPLER
            if (t < shadowDistance) {
                vec3 sp = distortShadow(sOrigin + sDir * t) * 0.5 + 0.5;
                if (sp.x > 0.0 && sp.x < 1.0 && sp.y > 0.0 && sp.y < 1.0 && sp.z < 1.0)
                    sh = texture(shadowtex0, sp);
            }
        #endif

        vec3 L = sunScatter * sh + ambScatter;
        float st = exp(-d * dt);
        scatter += L * T * (1.0 - st);
        T *= st;
    }
    return vec4(scatter, T);
}

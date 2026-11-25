// =====================================================================
//  Iluminacion forward para gbuffers (sol + cielo + antorchas)
// =====================================================================

const vec3 TORCH_COLOR = vec3(1.00, 0.58, 0.28);

vec3 blockLightColor(float lm) {
    float b = pow(lm, 2.6) * 1.4 + pow(lm, 9.0) * 1.2;
    return TORCH_COLOR * b * BLOCKLIGHT_INTENSITY;
}

float handLight(vec3 playerPos) {
    #ifdef HANDHELD_LIGHT
        float level = float(max(heldBlockLightValue, heldBlockLightValue2));
        if (level <= 0.0) return 0.0;
        float d = length(playerPos);
        return clamp((level - d) / 15.0, 0.0, 1.0);
    #else
        return 0.0;
    #endif
}

// alb: albedo lineal. N: normal mundo. lm: lightmap (block, sky).
// shadow: 0..1 ya calculada. sss: 0..1 (vegetacion).
vec3 shadeSurface(vec3 alb, vec3 N, vec2 lm, vec3 playerPos, float shadow, float sss,
                  vec3 lightDir, vec3 lightCol, vec3 ambient) {
    float NdotL = dot(N, lightDir);
    float diff = max(NdotL, 0.0);
    diff = mix(diff, abs(NdotL) * 0.5 + 0.35, sss);

    float sky = lm.y * lm.y;
    vec3 amb = ambient * sky * (0.70 + 0.30 * N.y);
    vec3 sun = lightCol * diff * shadow;
    float bl = max(lm.x, handLight(playerPos));
    vec3 blk = blockLightColor(bl);
    vec3 minL = vec3(0.010, 0.010, 0.013) * MIN_LIGHT + vec3(0.25) * nightVision;
    return alb * (amb + sun + blk + minL);
}

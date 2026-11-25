// Agua y bloques translucidos (cristal, hielo, slime...)
// El agua conserva su color vanilla (textura x tinte del bioma); el composite
// anade refraccion, absorcion por profundidad y reflejos.
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/sky.glsl"
#define WATER_WAVES_FUNC
#include "/lib/noise.glsl"
#include "/lib/wave.glsl"

#if defined OVERWORLD && defined SHADOWS
    #define USE_SHADOWS
#endif

#ifdef VSH
in vec4 mc_Entity;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 vColor;
out vec3 worldNormal;
out vec3 playerPos;
flat out int blockId;
flat out vec3 lightDir;
flat out vec3 lightCol;
flat out vec3 ambientCol;
flat out vec3 sunDir;
#ifdef USE_SHADOWS
#include "/lib/shadow.glsl"
out vec3 shadowClip;
#endif

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lmcoord = clamp(lmcoord * (33.05 / 32.0) - (1.05 / 32.0), 0.0, 1.0);
    vColor = gl_Color;
    blockId = int(mc_Entity.x + 0.5);

    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    playerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    worldNormal = normalize(mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal));
    gl_Position = ftransform();
    #ifdef WAVING_WATER
        if (blockId == ID_WATER) {
            vec3 wp = playerPos + cameraPosition;
            if (isFluidSurfaceVertex(wp)) {
                playerPos.y += waterVertexWave(wp);
                gl_Position = gl_ProjectionMatrix * (gbufferModelView * vec4(playerPos, 1.0));
            }
        }
    #endif

    #if defined OVERWORLD
        sunDir = getSunDir();
        lightDir = getLightDir();
        lightCol = getLightColor(sunDir.y);
        ambientCol = getAmbientColor(sunDir.y);
    #elif defined NETHER
        sunDir = vec3(0.0, 1.0, 0.0);
        lightDir = sunDir;
        lightCol = vec3(0.0);
        ambientCol = toLinear(fogColor) * 0.5 + vec3(0.20, 0.13, 0.09);
    #else
        sunDir = vec3(0.0, 1.0, 0.0);
        lightDir = sunDir;
        lightCol = vec3(0.0);
        ambientCol = vec3(0.16, 0.13, 0.22);
    #endif

    #ifdef USE_SHADOWS
        vec3 sp = playerPos + worldNormal * shadowNormalOffset(length(playerPos));
        shadowClip = (shadowProjection * (shadowModelView * vec4(sp, 1.0))).xyz;
    #endif
}
#endif

#ifdef FSH
#define SHADOW_SAMPLER
#ifdef USE_SHADOWS
#include "/lib/shadow.glsl"
#endif
#if defined OVERWORLD && defined CLOUD_SHADOWS && defined VOLUMETRIC_CLOUDS
#include "/lib/clouds.glsl"
#endif
#include "/lib/lighting.glsl"

uniform sampler2D gtexture;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 vColor;
in vec3 worldNormal;
in vec3 playerPos;
flat in int blockId;
flat in vec3 lightDir;
flat in vec3 lightCol;
flat in vec3 ambientCol;
flat in vec3 sunDir;
#ifdef USE_SHADOWS
in vec3 shadowClip;
#endif

/* RENDERTARGETS: 0,3,4,5 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out vec4 outColor3;
layout(location = 2) out vec4 outColor4;
layout(location = 3) out vec4 outColor5;

void main() {
    vec4 albedo = texture(gtexture, texcoord) * vColor;
    if (albedo.a < 0.01) discard;
    vec3 alb = toLinear(albedo.rgb);
    vec3 Ng = normalize(worldNormal);

    float shadow = 1.0;
    #ifdef OVERWORLD
        float skyGate = smoothstep(0.80, 0.97, lmcoord.y);
        shadow = skyGate;
        #ifdef USE_SHADOWS
            float s = sampleShadow(shadowClip, ign(gl_FragCoord.xy));
            if (s >= 0.0) {
                float fade = smoothstep(shadowDistance * 0.80, shadowDistance * 0.98, length(playerPos));
                shadow = mix(s, skyGate, fade);
            }
        #endif
        #if defined CLOUD_SHADOWS && defined VOLUMETRIC_CLOUDS
            if (shadow > 0.0) shadow *= getCloudShadow(playerPos + cameraPosition, lightDir);
        #endif
    #endif

    if (blockId == ID_WATER) {
        vec3 N = Ng;
        if (Ng.y > 0.5) N = waterNormal(playerPos + cameraPosition, length(playerPos));

        // Luz difusa sobre el agua (normal geometrica: superficie plana)
        float sky = lmcoord.y * lmcoord.y;
        vec3 light = ambientCol * sky
                   + lightCol * max(dot(Ng, lightDir), 0.0) * shadow * 0.65
                   + blockLightColor(max(lmcoord.x, handLight(playerPos)))
                   + vec3(0.010, 0.010, 0.013) * MIN_LIGHT + vec3(0.25) * nightVision;

        vec3 surface = alb * light;
        // color profundo: mismo tono vanilla, mas saturado y oscuro
        vec3 deep = pow(alb, vec3(1.45)) * 1.25 * light;

        // Reflejo de cielo de respaldo + brillo especular del sol
        vec3 V = normalize(playerPos);
        vec3 R = reflect(V, N);
        R.y = abs(R.y);
        vec3 refl = vec3(0.0);
        #ifdef OVERWORLD
            float skyOcc = smoothstep(0.4, 1.0, lmcoord.y);
            refl = getSkyColor(R, sunDir, false) * skyOcc;
            // Brillo del sol: GGX con rugosidad baja. El composite lo multiplica por
            // el Fresnel, asi que mirando hacia abajo es discreto y al atardecer
            // forma el camino de luz sobre el agua.
            vec3 H = normalize(lightDir - V);
            float NdotH = max(dot(N, H), 0.0);
            float a2 = 0.16 * 0.16;
            a2 *= a2;
            float dd = NdotH * NdotH * (a2 - 1.0) + 1.0;
            float D = a2 / (PI * dd * dd);
            float spec = min(D * 0.25 * max(dot(N, lightDir), 0.0), 25.0);
            refl += lightCol * spec * shadow * (1.0 - rainStrength) * smoothstep(0.0, 0.08, lightDir.y);
        #else
            refl = ambientCol * 0.6;
        #endif

        vec3 viewN = mat3(gbufferModelView) * N;
        outColor0 = vec4(surface, albedo.a * WATER_ALPHA);
        outColor3 = vec4(viewN, 1.0);
        outColor4 = vec4(deep, 1.0);
        outColor5 = vec4(refl, 1.0);
    } else {
        vec3 col = shadeSurface(alb, Ng, lmcoord, playerPos, shadow, 0.0, lightDir, lightCol, ambientCol);
        outColor0 = vec4(col, albedo.a);
        outColor3 = vec4(0.0, 0.0, 0.0, albedo.a);
        outColor4 = vec4(0.0, 0.0, 0.0, albedo.a);
        outColor5 = vec4(0.0, 0.0, 0.0, albedo.a);
    }
}
#endif

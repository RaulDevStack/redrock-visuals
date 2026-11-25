// Terreno, entidades, bloques-entidad y mano. Iluminacion forward.
// Defines opcionales: TERRAIN, ENTITIES, HAND (HAND escribe mascaras para el agua)
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/sky.glsl"
#include "/lib/wave.glsl"

#if defined OVERWORLD && defined SHADOWS
    #define USE_SHADOWS
#endif

#ifdef VSH
#ifdef TERRAIN
in vec4 mc_Entity;
in vec4 mc_midTexCoord;
#endif

out vec2 texcoord;
out vec2 lmcoord;
out vec4 vColor;
out vec3 worldNormal;
out vec3 playerPos;
flat out int blockId;
flat out vec3 lightDir;
flat out vec3 lightCol;
flat out vec3 ambientCol;
#ifdef USE_SHADOWS
#include "/lib/shadow.glsl"
out vec3 shadowClip;
#endif

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lmcoord = clamp(lmcoord * (33.05 / 32.0) - (1.05 / 32.0), 0.0, 1.0);
    vColor = gl_Color;

    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    playerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    worldNormal = normalize(mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal));

    blockId = 0;
    gl_Position = ftransform();
    #ifdef TERRAIN
        blockId = int(mc_Entity.x + 0.5);
        if (blockId >= ID_WATER && blockId <= ID_LAVA) {
            bool top = gl_MultiTexCoord0.t < mc_midTexCoord.t;
            vec3 off = terrainWave(blockId, playerPos + cameraPosition, top);
            if (off != vec3(0.0)) {
                playerPos += off;
                gl_Position = gl_ProjectionMatrix * (gbufferModelView * vec4(playerPos, 1.0));
            }
        }
    #endif

    #if defined OVERWORLD
        vec3 sunDir = getSunDir();
        lightDir = getLightDir();
        lightCol = getLightColor(sunDir.y);
        ambientCol = getAmbientColor(sunDir.y);
    #elif defined NETHER
        lightDir = vec3(0.0, 1.0, 0.0);
        lightCol = vec3(0.0);
        ambientCol = toLinear(fogColor) * 0.5 + vec3(0.20, 0.13, 0.09);
    #else
        lightDir = vec3(0.0, 1.0, 0.0);
        lightCol = vec3(0.0);
        ambientCol = vec3(0.16, 0.13, 0.22);
    #endif

    #ifdef USE_SHADOWS
        bool foliage = blockId == ID_PLANT || blockId == ID_LEAVES || blockId == ID_TALL_TOP;
        vec3 offsetDir = foliage ? lightDir : worldNormal;
        vec3 sp = playerPos + offsetDir * shadowNormalOffset(length(playerPos));
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
#include "/lib/noise.glsl"
#include "/lib/clouds.glsl"
#endif
#include "/lib/lighting.glsl"

uniform sampler2D gtexture;
#ifdef ENTITIES
uniform vec4 entityColor;
#endif

in vec2 texcoord;
in vec2 lmcoord;
in vec4 vColor;
in vec3 worldNormal;
in vec3 playerPos;
flat in int blockId;
flat in vec3 lightDir;
flat in vec3 lightCol;
flat in vec3 ambientCol;
#ifdef USE_SHADOWS
in vec3 shadowClip;
#endif

#ifdef HAND
/* RENDERTARGETS: 0,3,4,5 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out vec4 outColor3;
layout(location = 2) out vec4 outColor4;
layout(location = 3) out vec4 outColor5;
#else
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;
#endif

void main() {
    vec4 albedo = texture(gtexture, texcoord) * vColor;
    #ifdef ENTITIES
        albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
    #endif
    if (albedo.a < 0.1) discard;

    vec3 alb = toLinear(albedo.rgb);
    vec3 N = normalize(worldNormal);
    bool foliage = blockId == ID_PLANT || blockId == ID_LEAVES || blockId == ID_TALL_TOP;
    float sss = foliage ? 1.0 : 0.0;

    float shadow = 1.0;
    #ifdef OVERWORLD
        float NdotL = dot(N, lightDir);
        float skyGate = smoothstep(0.80, 0.97, lmcoord.y);   // evita luz solar en cuevas fuera del mapa
        shadow = skyGate;
        #ifdef USE_SHADOWS
            if (NdotL > 0.0 || foliage) {
                float s = sampleShadow(shadowClip, ign(gl_FragCoord.xy));
                if (s >= 0.0) {
                    float fade = smoothstep(shadowDistance * 0.80, shadowDistance * 0.98, length(playerPos));
                    shadow = mix(s, skyGate, fade);
                }
            } else {
                shadow = 0.0;
            }
        #endif
        #if defined CLOUD_SHADOWS && defined VOLUMETRIC_CLOUDS
            if (shadow > 0.0) shadow *= getCloudShadow(playerPos + cameraPosition, lightDir);
        #endif
    #endif

    vec3 col = shadeSurface(alb, N, lmcoord, playerPos, shadow, sss, lightDir, lightCol, ambientCol);

    #ifdef TERRAIN
        if (blockId == ID_EMISSIVE) {
            float m = smoothstep(0.45, 0.85, max(albedo.r, max(albedo.g, albedo.b)));
            col += alb * m * 4.0 * EMISSIVE_STRENGTH;
        } else if (blockId == ID_LAVA) {
            col += alb * 3.0 * EMISSIVE_STRENGTH;
        }
    #endif

    outColor0 = vec4(col, albedo.a);
    #ifdef HAND
        outColor3 = vec4(0.0, 0.0, 0.0, albedo.a);
        outColor4 = vec4(0.0, 0.0, 0.0, albedo.a);
        outColor5 = vec4(0.0, 0.0, 0.0, albedo.a);
    #endif
}
#endif

// Programas sencillos. Uno de estos defines selecciona el modo:
// BASIC, PARTICLES, WEATHER, EMISSIVE, GLINT, DAMAGED, SKYBASIC, SKYTEXTURED, CLOUDS
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/sky.glsl"

#if defined PARTICLES || defined WEATHER
    #define WRITE_MASKS
#endif

#ifdef VSH
out vec2 texcoord;
out vec2 lmcoord;
out vec4 vColor;
flat out vec3 lightCol;
flat out vec3 ambientCol;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lmcoord = clamp(lmcoord * (33.05 / 32.0) - (1.05 / 32.0), 0.0, 1.0);
    vColor = gl_Color;
    gl_Position = ftransform();

    #if defined OVERWORLD
        float h = getSunDir().y;
        lightCol = getLightColor(h);
        ambientCol = getAmbientColor(h);
    #elif defined NETHER
        lightCol = vec3(0.0);
        ambientCol = toLinear(fogColor) * 0.5 + vec3(0.20, 0.13, 0.09);
    #else
        lightCol = vec3(0.0);
        ambientCol = vec3(0.16, 0.13, 0.22);
    #endif
}
#endif

#ifdef FSH
#include "/lib/lighting.glsl"

uniform sampler2D gtexture;
uniform int renderStage;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 vColor;
flat in vec3 lightCol;
flat in vec3 ambientCol;

#ifdef WRITE_MASKS
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
    vec4 c;

#if defined CLOUDS
    discard;   // nubes vanilla desactivadas: usamos nubes volumetricas
#elif defined BASIC
    c = vColor;
    c.rgb = toLinear(c.rgb);
#elif defined SKYBASIC
    // Solo las estrellas: el cielo se dibuja en el pase deferred
    if (renderStage != MC_RENDER_STAGE_STARS) discard;
    c = vColor;
    c.rgb = toLinear(c.rgb) * 2.5 * (1.0 - rainStrength);
#elif defined SKYTEXTURED
    c = texture(gtexture, texcoord) * vColor;
    #ifdef OVERWORLD
        if (renderStage == MC_RENDER_STAGE_SUN) discard;   // sol procedural en el cielo
        c.rgb = toLinear(c.rgb) * 1.6 * (1.0 - rainStrength);
    #else
        c.rgb = toLinear(c.rgb);
    #endif
#elif defined EMISSIVE
    c = texture(gtexture, texcoord) * vColor;
    c.rgb = toLinear(c.rgb) * 3.0;
#elif defined GLINT
    c = texture(gtexture, texcoord) * vColor;
    c.rgb = toLinear(c.rgb) * 1.5;
#elif defined DAMAGED
    c = texture(gtexture, texcoord) * vColor;   // se mezcla multiplicando: sin conversion
#elif defined WEATHER
    c = texture(gtexture, texcoord) * vColor;
    if (c.a < 0.01) discard;
    float sky = lmcoord.y * lmcoord.y;
    c.rgb = toLinear(c.rgb) * (ambientCol * 1.2 + lightCol * 0.15) * sky
          + toLinear(c.rgb) * blockLightColor(lmcoord.x) * 0.5;
    c.a *= 0.55;
#else // PARTICLES
    c = texture(gtexture, texcoord) * vColor;
    if (c.a < 0.1) discard;
    float sky = lmcoord.y * lmcoord.y;
    vec3 alb = toLinear(c.rgb);
    c.rgb = alb * (ambientCol * sky + lightCol * 0.55 * sky + blockLightColor(lmcoord.x)
          + vec3(0.010, 0.010, 0.013) * MIN_LIGHT + vec3(0.25) * nightVision);
#endif

    outColor0 = c;
    #ifdef WRITE_MASKS
        outColor3 = vec4(0.0, 0.0, 0.0, c.a);
        outColor4 = vec4(0.0, 0.0, 0.0, c.a);
        outColor5 = vec4(0.0, 0.0, 0.0, c.a);
    #endif
}
#endif

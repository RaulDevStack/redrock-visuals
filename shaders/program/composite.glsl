// Composite 0: niebla volumetrica y nubes a resolucion reducida (VL_RES).
// Solo se calcula la esquina inferior izquierda del buffer; composite1 la reescala.
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/sky.glsl"
#include "/lib/noise.glsl"
#define SHADOW_SAMPLER
#ifdef SHADOWS
#include "/lib/shadow.glsl"
#endif
#include "/lib/clouds.glsl"
#include "/lib/volumetric.glsl"

#ifdef VSH
out vec2 texcoord;
void main() {
    gl_Position = ftransform();
    texcoord = gl_MultiTexCoord0.xy;
}
#endif

#ifdef FSH
uniform sampler2D depthtex0;
in vec2 texcoord;

/* RENDERTARGETS: 6,7 */
layout(location = 0) out vec4 outFog;
layout(location = 1) out vec4 outClouds;

void main() {
    outFog = vec4(0.0, 0.0, 0.0, 1.0);
    outClouds = vec4(0.0, 0.0, 0.0, 1.0);

    #ifdef OVERWORLD
    vec2 lowSize = ceil(vec2(viewWidth, viewHeight) * VL_RES);
    if (gl_FragCoord.x > lowSize.x || gl_FragCoord.y > lowSize.y) return;
    vec2 uv = min(gl_FragCoord.xy / lowSize, vec2(1.0));

    float depth = texture(depthtex0, uv).r;
    vec3 viewPos = screenToView(uv, depth);
    vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos;
    float dist = length(playerPos);
    vec3 dir = playerPos / dist;
    bool isSky = depth >= 1.0;
    float sceneDist = isSky ? 1e7 : dist;

    vec3 sunDir = getSunDir();
    vec3 lightDir = getLightDir();
    vec3 lightCol = getLightColor(sunDir.y);
    vec3 ambient = getAmbientColor(sunDir.y);
    float dither = ign(gl_FragCoord.xy);

    #ifdef VOLUMETRIC_CLOUDS
        vec3 horizon = getSkyColor(normalize(vec3(dir.x, 0.02, dir.z)), sunDir, false);
        outClouds = renderClouds(cameraPosition, dir, sceneDist, dither, lightDir, lightCol, ambient, horizon);
    #endif

    #ifdef VOLUMETRIC_FOG
        if (isEyeInWater == 0) {
            outFog = volumetricFog(dir, isSky ? 1e7 : dist, fract(dither + 0.5), sunDir, lightDir, lightCol, ambient);
        }
    #endif
    #endif
}
#endif

// Composite 1: agua (refraccion, absorcion, reflejos SSR), niebla de borde,
// nubes y niebla volumetrica reescaladas, niebla bajo el agua.
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/sky.glsl"

#ifdef VSH
out vec2 texcoord;
void main() {
    gl_Position = ftransform();
    texcoord = gl_MultiTexCoord0.xy;
}
#endif

#ifdef FSH
uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
in vec2 texcoord;

const vec4 colortex0ClearColor = vec4(0.0, 0.0, 0.0, 1.0);
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex4ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex5ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;

bool isWaterAt(vec2 uv) { return length(texture(colortex3, uv).xyz) > 0.5; }

#if defined VOXEL_REFLECTIONS && defined OVERWORLD && defined SHADOWS
#define USE_VOXELS
#define VOXEL_READ
#include "/lib/voxel.glsl"
#define SHADOW_SAMPLER
#include "/lib/shadow.glsl"

// Reflejo real: rayo por la rejilla de voxeles. Si el punto golpeado es visible
// en pantalla se usa el pixel real (textura completa); si no, el color del voxel iluminado.
// a = 1 si golpea algo.
vec4 voxelReflection(vec3 startPlayer, vec3 rdWorld, float dither) {
    vec3 hitP, hitN;
    uint data;
    if (!traceVoxels(startPlayer, rdWorld, hitP, hitN, data)) return vec4(0.0);

    vec3 sunDir = getSunDir();
    vec3 lightDir = getLightDir();
    vec3 alb = toLinear(voxelColor(data));
    float NdotL = max(dot(hitN, lightDir), 0.0);
    float sh = 0.0;
    if (NdotL > 0.0) {
        vec3 sp = hitP + hitN * 0.15;
        sh = sampleShadow((shadowProjection * (shadowModelView * vec4(sp, 1.0))).xyz, dither);
        if (sh < 0.0) sh = eyeSkyLight();
    }
    vec3 col = alb * (getAmbientColor(sunDir.y) * (0.70 + 0.30 * hitN.y)
                      + getLightColor(sunDir.y) * NdotL * sh
                      + vec3(0.010, 0.010, 0.013) * MIN_LIGHT)
             + alb * voxelEmission(data) * 4.0 * EMISSIVE_STRENGTH;

    // detalle completo cuando el punto es visible en pantalla
    vec3 hv = (gbufferModelView * vec4(hitP, 1.0)).xyz;
    if (hv.z < -near) {
        vec3 hs = viewToScreen(hv);
        if (all(greaterThan(hs.xy, vec2(0.0))) && all(lessThan(hs.xy, vec2(1.0)))) {
            float sd = texture(depthtex1, hs.xy).r;
            float sceneDist = length(screenToView(hs.xy, sd));
            float hd = length(hv);
            if (sd < 1.0 && abs(sceneDist - hd) < 0.35 + hd * 0.01) {
                vec2 e = smoothstep(0.0, 0.05, hs.xy) * (1.0 - smoothstep(0.95, 1.0, hs.xy));
                col = mix(col, texture(colortex0, hs.xy).rgb, e.x * e.y);
            }
        }
    }

    #ifdef BORDER_FOG
        float bf = smoothstep(far * 0.72, far, length(hitP.xz));
        col = mix(col, getSkyColor(normalize(vec3(rdWorld.x, max(rdWorld.y, 0.0), rdWorld.z)), sunDir, false), bf);
    #endif
    return vec4(col, 1.0);
}
#endif

#ifdef SSR
vec4 traceSSR(vec3 viewPos, vec3 rdir, float dither) {
    if (rdir.z > 0.2) return vec4(0.0);   // rayos hacia la camara: nunca aciertan
    float stepLen = 0.5 + length(viewPos) * 0.035;
    vec3 stepV = rdir * stepLen;
    vec3 pos = viewPos + stepV * dither;
    for (int i = 0; i < SSR_STEPS; i++) {
        pos += stepV;
        if (pos.z > -near) break;
        vec3 sp = viewToScreen(pos);
        if (sp.x < 0.0 || sp.x > 1.0 || sp.y < 0.0 || sp.y > 1.0) break;
        float sd = texture(depthtex1, sp.xy).r;
        if (sd < 1.0) {
            float sceneZ = screenToView(sp.xy, sd).z;
            float diff = sceneZ - pos.z;
            if (diff > 0.0 && diff < stepLen * 2.5 + 0.5) {
                // refinado binario
                vec3 a = pos - stepV;
                vec3 b = pos;
                for (int j = 0; j < 4; j++) {
                    vec3 m = (a + b) * 0.5;
                    vec3 msp = viewToScreen(m);
                    float mz = screenToView(msp.xy, texture(depthtex1, msp.xy).r).z;
                    if (mz > m.z) b = m; else a = m;
                }
                sp = viewToScreen(b);
                vec2 e = smoothstep(0.0, 0.07, sp.xy) * (1.0 - smoothstep(0.93, 1.0, sp.xy));
                return vec4(texture(colortex0, sp.xy).rgb, e.x * e.y);
            }
        }
        stepV *= 1.35;
        stepLen *= 1.35;
    }
    return vec4(0.0);
}
#endif

// Reescalado con respeto a la profundidad (evita halos en los bordes)
vec4 upsampleLowRes(sampler2D tex, vec2 uv, float centerZ) {
    vec2 screen = vec2(viewWidth, viewHeight);
    vec2 lowSize = ceil(screen * VL_RES);
    vec2 p = uv * lowSize - 0.5;
    vec2 base = floor(p);
    vec2 f = p - base;
    vec4 acc = vec4(0.0);
    float wsum = 0.0;
    for (int i = 0; i < 4; i++) {
        vec2 o = vec2(i & 1, i >> 1);
        vec2 ip = clamp(base + o, vec2(0.0), lowSize - 1.0);
        vec2 fullUV = (ip + 0.5) / lowSize;
        float z = -screenToView(fullUV, texture(depthtex0, fullUV).r).z;
        float wb = (o.x > 0.5 ? f.x : 1.0 - f.x) * (o.y > 0.5 ? f.y : 1.0 - f.y);
        float wd = 1.0 / (0.02 + abs(z - centerZ) / max(centerZ, 0.1));
        float w = wb * wd + 1e-5;
        acc += texture(tex, (ip + 0.5) / screen) * w;
        wsum += w;
    }
    return acc / wsum;
}

void main() {
    vec2 uv = texcoord;
    vec3 col = texture(colortex0, uv).rgb;
    float d0 = texture(depthtex0, uv).r;
    vec3 view0 = screenToView(uv, d0);
    vec3 player0 = mat3(gbufferModelViewInverse) * view0;
    float dist0 = length(view0);
    vec3 dir = player0 / max(dist0, 1e-4);
    bool isSky = d0 >= 1.0;
    float dither = ign(gl_FragCoord.xy);

    #ifdef OVERWORLD
        vec3 sunDir = getSunDir();
    #endif

    // ------------------------------------------------ agua
    vec4 n4 = texture(colortex3, uv);
    float k = length(n4.xyz);
    if (k > 0.5 && !isSky) {
        vec3 nV = n4.xyz / k;
        vec3 deep = texture(colortex4, uv).rgb / k;
        vec3 reflFallback = texture(colortex5, uv).rgb / k;
        vec3 nW = mat3(gbufferModelViewInverse) * nV;

        // refraccion: desplaza la imagen segun la ondulacion
        vec2 ruv = uv;
        if (nW.y > 0.3 && REFRACTION_STRENGTH > 0.0) {
            vec2 off = (mat3(gbufferModelView) * vec3(nW.x, 0.0, nW.z)).xy;
            off *= 0.06 * REFRACTION_STRENGTH / (1.0 + dist0 * 0.06);
            vec2 cand = clamp(uv + off, vec2(0.001), vec2(0.999));
            if (isWaterAt(cand) && texture(depthtex1, cand).r > d0) ruv = cand;
        }
        col = texture(colortex0, ruv).rgb;

        if (isEyeInWater == 0) {
            float d1 = texture(depthtex1, ruv).r;
            float thickness = d1 >= 1.0 ? 64.0 : max(length(screenToView(ruv, d1)) - dist0, 0.0);
            float absorb = 1.0 - exp(-thickness * WATER_FOG_DENSITY);
            col = mix(col, deep, absorb * 0.92);

            vec3 V = normalize(view0);
            float NdotV = clamp(dot(nV, -V), 0.0, 1.0);
            float F = 0.02 + 0.98 * pow(1.0 - NdotV, 5.0);
            vec3 refl = reflFallback;
            #if defined USE_VOXELS
                vec3 rdW = reflect(dir, mat3(gbufferModelViewInverse) * nV);
                vec4 vhit = voxelReflection(player0, normalize(rdW), dither);
                refl = mix(refl, vhit.rgb, vhit.a);
            #elif defined SSR
                vec3 rd = reflect(V, nV);
                vec4 hit = traceSSR(view0, rd, dither);
                refl = mix(refl, hit.rgb, hit.a);
            #endif
            col = mix(col, refl, F);
        } else {
            // vista desde abajo: reflexion interna total en angulos rasantes
            float NdotV = abs(dot(nV, normalize(view0)));
            col = mix(deep, col, smoothstep(0.55, 0.75, NdotV));
        }
    }

    // ------------------------------------------------ niebla de borde (oculta el fin de los chunks)
    #if defined BORDER_FOG && defined OVERWORLD
        if (!isSky && isEyeInWater == 0) {
            float hd = length(player0.xz);
            float bf = smoothstep(far * 0.72, far, hd);
            if (bf > 0.0) col = mix(col, getSkyColor(normalize(vec3(dir.x, max(dir.y, 0.0), dir.z)), sunDir, false), bf);
        }
    #endif

    // ------------------------------------------------ nubes + niebla volumetrica
    #ifdef OVERWORLD
        float centerZ = -view0.z;
        #ifdef VOLUMETRIC_CLOUDS
            vec4 cl = upsampleLowRes(colortex7, uv, centerZ);
            col = col * cl.a + cl.rgb;
        #endif
        #ifdef VOLUMETRIC_FOG
            if (isEyeInWater == 0) {
                vec4 fg = upsampleLowRes(colortex6, uv, centerZ);
                col = col * fg.a + fg.rgb;
            }
        #endif
    #endif

    // ------------------------------------------------ nether / end: niebla simple
    #if defined NETHER
        float nf = 1.0 - exp(-dist0 * 0.012);
        if (isSky) nf = 1.0;
        col = mix(col, toLinear(fogColor) * 0.6, nf * 0.85);
    #elif defined END
        float ef = 1.0 - exp(-dist0 * 0.004);
        if (!isSky) col = mix(col, vec3(0.05, 0.035, 0.07), ef);
    #endif

    // ------------------------------------------------ bajo el agua / lava / nieve polvo
    if (isEyeInWater == 1) {
        float light = 0.15 + 0.85 * eyeSkyLight();
        #ifdef OVERWORLD
            light *= 0.15 + 0.85 * smoothstep(-0.1, 0.2, sunDir.y);
        #endif
        vec3 wf = toLinear(fogColor) * light * 0.8;
        float f = 1.0 - exp(-dist0 * 0.055);
        col = mix(col, wf, f);
    } else if (isEyeInWater == 2) {
        col = mix(col, vec3(1.2, 0.35, 0.05), 1.0 - exp(-dist0 * 0.8));
    } else if (isEyeInWater == 3) {
        col = mix(col, vec3(0.75, 0.82, 0.9), 1.0 - exp(-dist0 * 0.6));
    }

    float dark = max(blindness, darknessFactor);
    if (dark > 0.0) col *= mix(1.0, exp(-dist0 * 0.25), dark);

    outColor0 = vec4(col, 1.0);
}
#endif

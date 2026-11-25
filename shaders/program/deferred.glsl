// Deferred: rellena el cielo procedural detras de la geometria opaca,
// antes de dibujar los translucidos (asi el agua y el cristal ven el cielo).
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
uniform sampler2D depthtex0;
in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;

void main() {
    vec4 c = texture(colortex0, texcoord);
    float d = texture(depthtex0, texcoord).r;
    if (d >= 1.0) {
        #if defined OVERWORLD
            vec3 dir = normalize(mat3(gbufferModelViewInverse) * screenToView(texcoord, 1.0));
            c.rgb += getSkyColor(dir, getSunDir(), true);
        #elif defined NETHER
            c.rgb = toLinear(fogColor) * 0.6;
        #endif
        c.rgb *= 1.0 - max(blindness, darknessFactor);
    }
    outColor0 = c;
}
#endif

// Final: bloom, exposicion, tonemap ACES, gradacion western suave, vineta.
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
in vec2 texcoord;

#ifdef BLOOM
const bool colortex0MipmapEnabled = true;
#endif

layout(location = 0) out vec4 outColor0;

vec3 acesFitted(vec3 x) {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void main() {
    vec2 uv = texcoord;
    vec3 col = texture(colortex0, uv).rgb;

    #ifdef BLOOM
        vec3 b = textureLod(colortex0, uv, 2.0).rgb * 0.30
               + textureLod(colortex0, uv, 3.0).rgb * 0.27
               + textureLod(colortex0, uv, 4.0).rgb * 0.23
               + textureLod(colortex0, uv, 5.0).rgb * 0.20;
        col = mix(col, b, 0.05 * BLOOM_STRENGTH);
    #endif

    // Exposicion: compensa cuevas y noche usando el brillo suavizado del ojo
    float expo = EXPOSURE;
    float eyeSky = eyeSkyLight();
    #ifdef OVERWORLD
        float day = smoothstep(-0.12, 0.20, getSunDir().y);
        expo *= mix(1.0, mix(2.6, 1.0, day), eyeSky);
    #endif
    expo *= mix(2.2, 1.0, eyeSky);
    col *= expo;

    col = acesFitted(col);

    // Gradacion western suave
    float g = WESTERN_GRADE;
    col *= mix(vec3(1.0), vec3(1.06, 1.00, 0.88), g);
    float l = luminance(col);
    // sombras marron calido, luces doradas
    col = mix(col, col * vec3(1.04, 0.98, 0.90), g * (1.0 - l) * 0.5);
    col = mix(vec3(l), col, SATURATION - 0.05 * g);
    col = clamp(col, 0.0, 1.0);
    col = mix(col, col * col * (3.0 - 2.0 * col), 0.30 * CONTRAST);
    col += vec3(0.010, 0.006, 0.002) * g * (1.0 - l);

    // Vineta
    vec2 c = uv - 0.5;
    col *= 1.0 - dot(c, c) * VIGNETTE * 1.6;

    col = toSRGB(col);
    col += (ign(gl_FragCoord.xy) - 0.5) / 255.0;   // dithering anti-bandas
    outColor0 = vec4(col, 1.0);
}
#endif

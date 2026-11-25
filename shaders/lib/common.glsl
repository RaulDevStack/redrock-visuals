// =====================================================================
//  Uniforms y utilidades comunes
// =====================================================================

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform vec3 fogColor;

uniform float frameTimeCounter;
uniform float sunAngle;
uniform float rainStrength;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;
uniform float nightVision;
uniform float blindness;
uniform float darknessFactor;

uniform int isEyeInWater;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform ivec2 eyeBrightnessSmooth;

const float PI = 3.14159265359;

vec3 toLinear(vec3 c) { return c * c * (c * 0.2 + 0.8) ; }   // aproximacion barata de pow(c, 2.2)
vec3 toSRGB(vec3 c)   { return pow(max(c, 0.0), vec3(1.0 / 2.2)); }

float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

vec3 screenToView(vec2 uv, float depth) {
    vec4 p = gbufferProjectionInverse * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
    return p.xyz / p.w;
}

vec3 viewToScreen(vec3 v) {
    vec4 p = gbufferProjection * vec4(v, 1.0);
    return (p.xyz / p.w) * 0.5 + 0.5;
}

// Interleaved gradient noise (dithering barato, sin texturas)
float ign(vec2 fragCoord) {
    return fract(52.9829189 * fract(dot(fragCoord, vec2(0.06711056, 0.00583715))));
}

float eyeSkyLight() { return float(eyeBrightnessSmooth.y) / 240.0; }

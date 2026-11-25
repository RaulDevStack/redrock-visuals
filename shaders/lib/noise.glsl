// =====================================================================
//  Ruido basado en textura (tex/noise.png, 256x256, filtrado lineal, repetido)
//  R = ruido blanco, G = R desplazado (37,17) -> ruido 3D con 1 sola lectura
// =====================================================================

uniform sampler2D noisetex;

float noise2D(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return texture(noisetex, (i + f + 0.5) / 256.0).r;
}

float noise3D(vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    vec2 uv = i.xz + vec2(37.0, 17.0) * i.y + f.xz;
    vec2 rg = texture(noisetex, (uv + 0.5) / 256.0).rg;
    return mix(rg.x, rg.y, f.y);
}

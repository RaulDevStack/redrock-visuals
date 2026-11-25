// Pase de sombras (+ voxelizacion para los reflejos reales)
#include "/lib/voxel_opts.glsl"
#if defined VSH && defined VOXEL_REFLECTIONS
#extension GL_ARB_shader_image_load_store : enable
#endif
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/shadow.glsl"
#include "/lib/wave.glsl"

#ifdef VSH
in vec4 mc_Entity;
in vec4 mc_midTexCoord;
out vec2 texcoord;
out vec4 vColor;

#ifdef VOXEL_REFLECTIONS
#include "/lib/voxel.glsl"
in vec4 at_midBlock;
uniform int renderStage;
uniform sampler2D gtexture;
layout(r32ui) uniform uimage3D voxelImg;

void voxelize(int id) {
    if (renderStage != MC_RENDER_STAGE_TERRAIN_SOLID &&
        renderStage != MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED &&
        renderStage != MC_RENDER_STAGE_TERRAIN_CUTOUT) return;
    if (id == ID_PLANT || id == ID_TALL_TOP || id == ID_WATER) return;
    // solo vertices en las esquinas de un cubo completo (descarta vallas, antorchas...)
    vec3 toCenter = at_midBlock.xyz / 64.0;
    if (any(lessThan(abs(toCenter), vec3(0.49)))) return;

    vec3 playerPos = (shadowModelViewInverse * (gl_ModelViewMatrix * gl_Vertex)).xyz;
    ivec3 cell = ivec3(floor(playerToVoxel(playerPos + toCenter)));
    if (!insideVoxelVolume(cell)) return;

    vec3 col = textureLod(gtexture, mc_midTexCoord.st, 4.0).rgb * gl_Color.rgb;
    // prioridad: caras laterales > superior > inferior (las laterales son las que mas se reflejan)
    uint pri = abs(gl_Normal.y) < 0.5 ? 3u : (gl_Normal.y > 0.0 ? 2u : 1u);
    imageAtomicMax(voxelImg, cell, packVoxel(col, at_midBlock.w, pri));
}
#endif

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vColor = gl_Color;
    int id = int(mc_Entity.x + 0.5);
    #ifdef VOXEL_REFLECTIONS
        voxelize(id);
    #endif
    if (id == ID_WATER) {           // el agua no proyecta sombra
        gl_Position = vec4(10.0, 10.0, 10.0, 1.0);
        return;
    }
    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    if (id > ID_WATER && id <= ID_LAVA) {
        vec3 playerPos = (shadowModelViewInverse * viewPos).xyz;
        bool top = gl_MultiTexCoord0.t < mc_midTexCoord.t;
        vec3 off = terrainWave(id, playerPos + cameraPosition, top);
        if (off != vec3(0.0)) viewPos = shadowModelView * vec4(playerPos + off, 1.0);
    }
    gl_Position = gl_ProjectionMatrix * viewPos;
    gl_Position.xyz = distortShadow(gl_Position.xyz);
}
#endif

#ifdef FSH
uniform sampler2D gtexture;
in vec2 texcoord;
in vec4 vColor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;

void main() {
    vec4 c = texture(gtexture, texcoord) * vColor;
    if (c.a < 0.1) discard;
    outColor0 = c;
}
#endif

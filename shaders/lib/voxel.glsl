// =====================================================================
//  Reflejos reales por voxeles
//  El pase de sombras escribe cada bloque cubico cercano en una textura 3D
//  (color medio + emision). composite1 lanza rayos por esa rejilla, asi que
//  los reflejos muestran tambien lo que esta fuera de la pantalla o tapado.
// =====================================================================

const ivec3 VOXEL_SIZE = ivec3(256, 128, 256);
const ivec3 VOXEL_HALF = ivec3(128, 64, 128);

// Posicion relativa a la camara -> coordenada continua de la rejilla
vec3 playerToVoxel(vec3 playerPos) {
    return playerPos + fract(cameraPosition) + vec3(VOXEL_HALF);
}

bool insideVoxelVolume(ivec3 c) {
    return all(greaterThanEqual(c, ivec3(0))) && all(lessThan(c, VOXEL_SIZE));
}

// prioridad (2 bits) | emision (4) | R G B (8 cada uno)
uint packVoxel(vec3 srgb, float emission, uint priority) {
    uvec3 c = uvec3(clamp(srgb, 0.0, 1.0) * 255.0 + 0.5);
    uint em = uint(clamp(emission, 0.0, 15.0));
    return (priority << 28u) | (em << 24u) | (c.r << 16u) | (c.g << 8u) | c.b;
}

vec3 voxelColor(uint v) {
    return vec3(float((v >> 16u) & 255u), float((v >> 8u) & 255u), float(v & 255u)) / 255.0;
}

float voxelEmission(uint v) {
    return float((v >> 24u) & 15u) / 15.0;
}

#ifdef VOXEL_READ
uniform usampler3D voxelSampler;

// DDA (Amanatides & Woo). Devuelve true si golpea un bloque.
bool traceVoxels(vec3 startPlayer, vec3 rd, out vec3 hitPlayer, out vec3 hitNormal, out uint hitData) {
    vec3 origin = playerToVoxel(startPlayer) + rd * 0.02;
    ivec3 cell = ivec3(floor(origin));
    vec3 stepDir = vec3(rd.x >= 0.0 ? 1.0 : -1.0, rd.y >= 0.0 ? 1.0 : -1.0, rd.z >= 0.0 ? 1.0 : -1.0);
    vec3 invRd = 1.0 / max(abs(rd), vec3(1e-6));
    vec3 tDelta = invRd;
    vec3 tMax = (stepDir * (vec3(cell) - origin) + max(stepDir, 0.0)) * invRd;

    float t = 0.0;
    vec3 n = vec3(0.0, 1.0, 0.0);
    hitPlayer = vec3(0.0);
    hitNormal = n;
    hitData = 0u;
    for (int i = 0; i < VOXEL_STEPS; i++) {
        if (tMax.x < tMax.y && tMax.x < tMax.z) {
            t = tMax.x; tMax.x += tDelta.x; cell.x += int(stepDir.x); n = vec3(-stepDir.x, 0.0, 0.0);
        } else if (tMax.y < tMax.z) {
            t = tMax.y; tMax.y += tDelta.y; cell.y += int(stepDir.y); n = vec3(0.0, -stepDir.y, 0.0);
        } else {
            t = tMax.z; tMax.z += tDelta.z; cell.z += int(stepDir.z); n = vec3(0.0, 0.0, -stepDir.z);
        }
        if (!insideVoxelVolume(cell)) return false;
        uint v = texelFetch(voxelSampler, cell, 0).r;
        if (v != 0u) {
            hitPlayer = startPlayer + rd * (0.02 + t);
            hitNormal = n;
            hitData = v;
            return true;
        }
    }
    return false;
}
#endif

// =====================================================================
//  Redrock Visuals - opciones del shader (aparecen en el menu de Iris)
// =====================================================================

#include "/lib/voxel_opts.glsl"

// ---------- Sombras ----------
#define SHADOWS
const int shadowMapResolution = 1536; // [512 1024 1536 2048 3072 4096]
const float shadowDistance = 96.0; // [48.0 64.0 80.0 96.0 128.0 160.0 192.0]
const float shadowDistanceRenderMul = 1.0;
const float sunPathRotation = -25.0; // [-40.0 -30.0 -25.0 -20.0 -10.0 0.0 10.0 20.0 30.0 40.0]
const bool shadowHardwareFiltering = true;
const float shadowIntervalSize = 2.0;
#define SHADOW_FILTER 1 // [0 1 2]
#define CLOUD_SHADOWS

// ---------- Iluminacion ----------
#define SUN_INTENSITY 1.0 // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.75 2.0]
#define MOON_INTENSITY 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0]
#define AMBIENT_INTENSITY 1.0 // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.75 2.0]
#define BLOCKLIGHT_INTENSITY 1.0 // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.75 2.0]
#define MIN_LIGHT 1.0 // [0.0 0.5 1.0 1.5 2.0 3.0 4.0]
#define EMISSIVE_STRENGTH 1.0 // [0.0 0.5 1.0 1.5 2.0 3.0]
#define HANDHELD_LIGHT

// ---------- Movimiento ----------
#define WAVING_PLANTS
#define WAVING_LEAVES
#define WAVING_WATER
#define WAVING_LAVA
#define WAVING_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0]
#define WAVING_SPEED 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define WAVING_WATER_HEIGHT 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define WAVING_LAVA_HEIGHT 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0]

// ---------- Atmosfera / niebla ----------
#define VOLUMETRIC_FOG
#define VL_STEPS 8 // [4 6 8 10 12 16 24]
#define VL_RES 0.5 // [0.25 0.5 1.0]
#define FOG_DENSITY 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0 2.5 3.0 4.0]
#define FOG_HEIGHT 66.0 // [40.0 50.0 56.0 60.0 63.0 66.0 70.0 80.0 90.0 100.0 120.0]
#define FOG_FALLOFF 28.0 // [10.0 15.0 20.0 28.0 35.0 45.0 60.0]
#define VL_INTENSITY 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0]
#define MORNING_FOG
#define DUST_NOISE
#define BORDER_FOG

// ---------- Nubes volumetricas ----------
#define VOLUMETRIC_CLOUDS
#define CLOUD_STEPS 10 // [6 8 10 12 16 20 24 32]
#define CLOUD_LIGHT_STEPS 2 // [1 2 3 4]
#define CLOUD_HEIGHT 210.0 // [160.0 180.0 192.0 210.0 230.0 256.0 300.0 350.0]
#define CLOUD_THICKNESS 90.0 // [40.0 60.0 75.0 90.0 110.0 130.0 160.0]
#define CLOUD_COVERAGE 0.40 // [0.10 0.20 0.30 0.35 0.40 0.45 0.50 0.60 0.70 0.80]
#define CLOUD_DENSITY 1.0 // [0.5 0.75 1.0 1.25 1.5 2.0]
#define CLOUD_SPEED 1.0 // [0.0 0.25 0.5 1.0 1.5 2.0 3.0]
#define CLOUD_FAR 2500.0 // [1000.0 1500.0 2000.0 2500.0 3000.0 4000.0]

// ---------- Agua ----------
#define SSR
#define SSR_STEPS 12 // [8 12 16 20 24 32]
#define VOXEL_STEPS 96 // [48 64 96 128 192 256]
#define WATER_ALPHA 0.65 // [0.3 0.4 0.5 0.55 0.6 0.65 0.7 0.8 0.9 1.0]
#define WATER_FOG_DENSITY 0.10 // [0.02 0.04 0.06 0.08 0.10 0.13 0.16 0.20 0.30]
#define WAVE_STRENGTH 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define WAVE_SPEED 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define REFRACTION_STRENGTH 1.0 // [0.0 0.5 1.0 1.5 2.0]

// ---------- Post-procesado ----------
#define EXPOSURE 0.9 // [0.5 0.6 0.7 0.8 0.85 0.9 0.95 1.0 1.1 1.2 1.3 1.4 1.5 1.75 2.0]
#define BLOOM
#define BLOOM_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0]
#define WESTERN_GRADE 0.5 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5]
#define SATURATION 1.05 // [0.6 0.7 0.8 0.9 1.0 1.05 1.1 1.2 1.3]
#define CONTRAST 1.0 // [0.0 0.5 0.75 1.0 1.25 1.5 2.0]
#define VIGNETTE 0.25 // [0.0 0.1 0.2 0.25 0.3 0.4 0.5 0.7]

// ---------- Buffers ----------
/*
const int colortex0Format = RGBA16F;
const int colortex3Format = RGBA16F;
const int colortex4Format = RGBA16F;
const int colortex5Format = RGBA16F;
const int colortex6Format = RGBA16F;
const int colortex7Format = RGBA16F;
*/
// colortex0 : escena HDR lineal
// colortex3 : normal del agua (view space) - escalada por la cobertura
// colortex4 : color profundo del agua (derivado del color vanilla)
// colortex5 : reflejo de cielo + brillo del sol sobre el agua
// colortex6 : niebla volumetrica (baja resolucion)  rgb = luz dispersada, a = transmitancia
// colortex7 : nubes volumetricas (baja resolucion)  rgb = luz dispersada, a = transmitancia

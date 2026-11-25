// Opcion separada porque debe leerse ANTES de cualquier codigo
// (activa una extension de OpenGL en el pase de sombras).
#ifndef VOXEL_OPTS_INCLUDED
#define VOXEL_OPTS_INCLUDED

//#define VOXEL_REFLECTIONS

// Sin imagenes personalizadas en esta version de Iris: se vuelve a SSR
#if defined VOXEL_REFLECTIONS && !defined IRIS_FEATURE_CUSTOM_IMAGES
    #undef VOXEL_REFLECTIONS
#endif

#endif

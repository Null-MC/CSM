#define WORLD_OVERWORLD
#define WORLD_SKY_ENABLED
#define WORLD_SHADOW_ENABLED
//#define SHADOW_ENABLED

/*
const int shadowtex0Format = R32F;
const int shadowtex1Format = R32F;
const int shadowcolor0Format = RGBA8;
*/

const bool shadowcolor0Nearest = false;
const vec4 shadowcolor0ClearColor = vec4(1.0, 1.0, 1.0, 0.0);
const bool shadowcolor0Clear = true;

const float shadowDistanceRenderMul = 1.0;

const float shadowDistance = 150; // [50 100 150 200 300 400 800]
const int shadowMapResolution = 2048; // [128 256 512 1024 2048 4096 8192]

#ifdef MC_SHADOW_QUALITY
    const float shadowMapSize = shadowMapResolution * MC_SHADOW_QUALITY;
#else
    const float shadowMapSize = shadowMapResolution;
#endif

const float shadowPixelSize = 1.0 / shadowMapSize;

const bool generateShadowMipmap = false;
const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;

#ifdef SHADOW_ENABLE_HWCOMP
    const bool shadowHardwareFiltering = true;
    const bool shadowtex0Nearest = false;
    const bool shadowtex1Nearest = false;
#else
    const bool shadowHardwareFiltering = false;
    const bool shadowtex0Nearest = true;
    const bool shadowtex1Nearest = true;
#endif

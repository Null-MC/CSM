const int shadowMapResolution = 2048; // [128 256 512 1024 2048 4096 8192]
const float shadowDistanceRenderMul = 1.0;

#define SHADOW_TYPE 3 // [0 1 2 3]
#define LIGHTING_TYPE 0 // [0 1 2]

// Shadow Options
//#define SHADOW_EXCLUDE_ENTITIES
//#define SHADOW_EXCLUDE_FOLIAGE
#define SHADOW_COLORS 0 // [0 1 2]
#define SHADOW_BRIGHTNESS 0.05 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define SHADOW_BIAS_SCALE 1.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5]
#define SHADOW_DISTORT_FACTOR 0.05 // [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.60 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.80 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.90 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.00]
#define SHADOW_ENTITY_CASCADE 1 // [0 1 2 3]
#define SHADOW_CSM_FITWORLD
#define SHADOW_FILTER 0 // [0 1 2]

// World Options
#define ENABLE_WAVING

// Debug Options
#define DEBUG_SHADOW_BUFFER 0 // [0 1 2 3]
//#define DEBUG_CASCADE_TINT
#define DEBUG_CSM_FRUSTUM

// Internal Options
#define SHADOW_BIAS 0.035
#define SHADOW_CSM_FIT_FARSCALE 1.1
#define LOD_TINT_FACTOR 0.4
#define CSM_PLAYER_ID 0

#define PI 3.1415926538
#define EPSILON 1e-6
#define GAMMA 2.2


#if SHADOW_TYPE != 3
	#undef DEBUG_CASCADE_TINT
#endif

#if SHADOW_TYPE != 3 || defined SHADOW_CSM_FITWORLD
	const float shadowDistance = 800; // [100 200 300 800]
#else
	// WARNING: This must match the value of the final cascade in "~/lib/shadow/csm.glsl" [+20] !
	const float shadowDistance = 100;
#endif


vec3 RGBToLinear(const in vec3 color) {
	return pow(color, vec3(GAMMA));
}

vec3 LinearToRGB(const in vec3 color) {
	return pow(color, vec3(1.0 / GAMMA));
}
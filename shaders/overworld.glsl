const float shadowDistance = 800; // [50 100 150 200 300 400 800]
const int shadowMapResolution = 2048; // [128 256 512 1024 2048 4096 8192]

#define SHADOW_PCF_SIZE 0.015 // [0.005 0.010 0.015 0.020 0.025 0.030]

const float shadowPixelSize = 1.0 / shadowMapResolution;

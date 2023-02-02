//#define RENDER_SETUP_DISKS
#define RENDER_SETUP
#define RENDER_COMPUTE

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

const ivec3 workGroups = ivec3(1, 1, 1);

#if defined IRIS_FEATURE_SSBO && defined WORLD_SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
    layout(std430, binding = 1) buffer shadowDiskData {
        vec2 pcfDiskOffset[32];     // 256
        vec2 pcssDiskOffset[32];    // 256
    };
#endif


void main() {
    #if defined IRIS_FEATURE_SSBO && defined WORLD_SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        const float goldenAngle = PI * (3.0 - sqrt(5.0));
        const float PHI = (1.0 + sqrt(5.0)) / 2.0;

        for (int i = 0; i < SHADOW_PCF_SAMPLES; i++) {
            float r = sqrt((i + 0.5) / SHADOW_PCF_SAMPLES);
            float theta = i * goldenAngle + PHI;
            
            float sine = sin(theta);
            float cosine = cos(theta);
            
            pcfDiskOffset[i] = vec2(cosine, sine) * r;
        }

        for (int i = 0; i < SHADOW_PCSS_SAMPLES; i++) {
            float r = sqrt((i + 0.5) / SHADOW_PCSS_SAMPLES);
            float theta = i * goldenAngle + PHI;
            
            float sine = sin(theta);
            float cosine = cos(theta);
            
            pcssDiskOffset[i] = vec2(cosine, sine) * r;
        }
    #endif

    barrier();
}

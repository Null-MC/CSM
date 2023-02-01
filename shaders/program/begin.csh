//#define RENDER_BEGIN_CSM
#define RENDER_BEGIN
#define RENDER_COMPUTE

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

const ivec3 workGroups = ivec3(4, 1, 1);

#if defined IRIS_FEATURE_SSBO && defined WORLD_SHADOW_ENABLED && SHADOW_TYPE == SHADOW_TYPE_CASCADED
    layout(std430, binding = 0) buffer csmData {
        float cascadeSize[4];           // 16
        vec2 shadowProjectionSize[4];   // 32
        vec2 shadowProjectionPos[4];    // 32
        mat4 cascadeProjection[4];      // 256

        vec3 cascadeViewMin[4];         // 48
        vec3 cascadeViewMax[4];         // 48
    };

    uniform mat4 gbufferModelView;
    uniform mat4 gbufferProjection;
    uniform mat4 shadowModelView;
    uniform float near;
    uniform float far;

    #include "/lib/shadows/csm.glsl"
#endif


void main() {
    #if defined IRIS_FEATURE_SSBO && defined WORLD_SHADOW_ENABLED && SHADOW_TYPE == SHADOW_TYPE_CASCADED
        float cascadeSizes[4];
        cascadeSizes[0] = GetCascadeDistance(0);
        cascadeSizes[1] = GetCascadeDistance(1);
        cascadeSizes[2] = GetCascadeDistance(2);
        cascadeSizes[3] = GetCascadeDistance(3);

        int i = int(gl_GlobalInvocationID.x);

        cascadeSize[i] = cascadeSizes[i];
        shadowProjectionPos[i] = GetShadowTilePos(i);
        cascadeProjection[i] = GetShadowTileProjectionMatrix(cascadeSizes, i);

        shadowProjectionSize[i] = 2.0 / vec2(
            cascadeProjection[i][0].x,
            cascadeProjection[i][1].y);

        mat4 cascadeProjectionInv[4];
        cascadeProjectionInv[0] = inverse(cascadeProjection[0]);
        cascadeProjectionInv[1] = inverse(cascadeProjection[1]);
        cascadeProjectionInv[2] = inverse(cascadeProjection[2]);
        cascadeProjectionInv[3] = inverse(cascadeProjection[3]);

        cascadeViewMin[0] = (cascadeProjectionInv[0] * vec4(vec3(-1.0), 1.0)).xyz;
        cascadeViewMax[0] = (cascadeProjectionInv[0] * vec4(vec3( 1.0), 1.0)).xyz;

        cascadeViewMin[1] = (cascadeProjectionInv[1] * vec4(vec3(-1.0), 1.0)).xyz;
        cascadeViewMax[1] = (cascadeProjectionInv[1] * vec4(vec3( 1.0), 1.0)).xyz;

        cascadeViewMin[2] = (cascadeProjectionInv[2] * vec4(vec3(-1.0), 1.0)).xyz;
        cascadeViewMax[2] = (cascadeProjectionInv[2] * vec4(vec3( 1.0), 1.0)).xyz;

        cascadeViewMin[3] = (cascadeProjectionInv[3] * vec4(vec3(-1.0), 1.0)).xyz;
        cascadeViewMax[3] = (cascadeProjectionInv[3] * vec4(vec3( 1.0), 1.0)).xyz;
    #endif

    barrier();
}

#define RENDER_SHADOW
#define RENDER_GEOMETRY

#include "/lib/common.glsl"
#include "/lib/constants.glsl"

layout(triangles) in;
layout(triangle_strip, max_vertices=12) out;

in vec2 vTexcoord[3];
in vec4 vColor[3];

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    flat in vec3 vOriginPos[3];
    flat in int vBlockId[3];
    flat in int vEntityId[3];
#endif

out vec2 gTexcoord;
out vec4 gColor;

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    flat out vec2 gShadowTilePos;
#endif

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform vec3 cameraPosition;
uniform int renderStage;

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    uniform float near;
    uniform float far;

    #ifndef IS_IRIS
        // NOTE: We are using the previous gbuffer matrices cause the current ones don't work in shadow pass
        uniform mat4 gbufferPreviousModelView;
        uniform mat4 gbufferPreviousProjection;
    #else
        uniform mat4 gbufferModelView;
        uniform mat4 gbufferProjection;
    #endif

    #include "/lib/shadows/csm.glsl"
#elif SHADOW_TYPE != SHADOW_TYPE_NONE
    #include "/lib/shadows/basic.glsl"
#endif


void main() {
    #ifdef SHADOW_EXCLUDE_ENTITIES
        if (vEntityId[0] == 0) return;
    #endif

    #ifdef SHADOW_EXCLUDE_FOLIAGE
        if (vBlockId[0] >= 10000 && vBlockId[0] <= 10004) return;
    #endif

    //if (vEntityId[0] == MATERIAL_LIGHTNING_BOLT) return;

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        #ifndef IRIS_FEATURE_SSBO
            mat4 cascadeProjection[4];
            cascadeProjection[0] = GetShadowTileProjectionMatrix(0);
            cascadeProjection[1] = GetShadowTileProjectionMatrix(1);
            cascadeProjection[2] = GetShadowTileProjectionMatrix(2);
            cascadeProjection[3] = GetShadowTileProjectionMatrix(3);
        #endif

        int shadowTile = GetShadowTile(cascadeProjection, vOriginPos[0]);
        if (shadowTile < 0) return;

        #ifndef SHADOW_EXCLUDE_ENTITIES
            if (renderStage == MC_RENDER_STAGE_ENTITIES && vEntityId[0] == CSM_PLAYER_ID) shadowTile = 0;
        #endif

        #ifdef SHADOW_CSM_OVERLAP
            int cascadeMin = max(shadowTile - 1, 0);
            int cascadeMax = min(shadowTile + 1, 3);
        #else
            int cascadeMin = shadowTile;
            int cascadeMax = shadowTile;
        #endif

        for (int c = cascadeMin; c <= cascadeMax; c++) {
            if (c != shadowTile) {
                #ifdef SHADOW_CSM_OVERLAP
                    // duplicate geometry if intersecting overlapping cascades
                    if (!CascadeIntersectsProjection(vOriginPos[0], cascadeProjection[c])) continue;
                #else
                    continue;
                #endif
            }

            #ifndef IRIS_FEATURE_SSBO
                vec2 shadowTilePos = GetShadowTilePos(c);
            #endif

            for (int v = 0; v < 3; v++) {
                #ifdef IRIS_FEATURE_SSBO
                    gShadowTilePos = shadowProjectionPos[c];
                #else
                    gShadowTilePos = shadowTilePos;
                #endif

                gTexcoord = vTexcoord[v];
                gColor = vColor[v];

                gl_Position = cascadeProjection[c] * gl_in[v].gl_Position;

                gl_Position.xy = gl_Position.xy * 0.5 + 0.5;
                gl_Position.xy = gl_Position.xy * 0.5 + shadowTilePos;
                gl_Position.xy = gl_Position.xy * 2.0 - 1.0;

                EmitVertex();
            }

            EndPrimitive();
        }
    #else
        for (int v = 0; v < 3; v++) {
            gTexcoord = vTexcoord[v];
            gColor = vColor[v];

            gl_Position = gl_ProjectionMatrix * gl_in[v].gl_Position;

            #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                gl_Position.xyz = distort(gl_Position.xyz);
            #endif

            EmitVertex();
        }

        EndPrimitive();
    #endif
}

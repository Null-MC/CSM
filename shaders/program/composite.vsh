#define RENDER_COMPOSITE
#define RENDER_VERTEX

#include "/lib/common.glsl"
#include "/lib/constants.glsl"

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
	uniform mat4 shadowModelView;
	uniform float near;
	uniform float far;
#endif

out vec2 texcoord;

#if defined DEBUG_CSM_FRUSTUM && SHADOW_TYPE == 3 && DEBUG_SHADOW_BUFFER != 0
	out vec3 shadowTileColors[4];
	out mat4 matShadowToScene[4];

    #ifdef SHADOW_CSM_TIGHTEN
        out vec3 clipSize[4];
    #else
    	out vec3 clipMin[4];
    	out vec3 clipMax[4];
    #endif
#endif

#if SHADOW_TYPE == 3
    #ifdef IS_OPTIFINE
        uniform mat4 gbufferPreviousModelView;
    	uniform mat4 gbufferPreviousProjection;
    #endif

	uniform mat4 gbufferModelView;
	uniform mat4 gbufferProjection;
	uniform mat4 shadowProjection;
	
	#include "/lib/shadows/csm.glsl"
#endif


void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	#if SHADOW_TYPE == SHADOW_TYPE_CASCADED && defined DEBUG_CSM_FRUSTUM && DEBUG_SHADOW_BUFFER != 0
		//mat4 matShadowModelView = GetShadowModelViewMatrix();

		for (int tile = 0; tile < 4; tile++) {
			//vec2 shadowTilePos = GetShadowTilePos(tile);
			shadowTileColors[tile] = GetShadowTileColor(tile);

			#ifdef IS_IRIS
				float rangeNear = tile > 0 ? cascadeSize[tile - 1] : near;
				float rangeFar = cascadeSize[tile];
			#else
				float rangeNear = tile > 0 ? GetCascadeDistance(tile - 1) : near;
				float rangeFar = GetCascadeDistance(tile);
			#endif

			mat4 matSceneProjectionRanged = gbufferProjection;
			SetProjectionRange(matSceneProjectionRanged, rangeNear, rangeFar);

			#ifndef IS_IRIS
				mat4 cascadeProjection = GetShadowTileProjectionMatrix(tile);
			#endif
			
			mat4 matShadowWorldViewProjectionInv = inverse(cascadeProjection * shadowModelView);
			matShadowToScene[tile] = matSceneProjectionRanged * gbufferModelView * matShadowWorldViewProjectionInv;

            #ifdef SHADOW_CSM_TIGHTEN
                clipSize[tile] = GetCascadePaddedFrustumClipBounds(cascadeProjection, -1.5);
            #else
                // project frustum points
                mat4 matModelViewProjectionInv = inverse(matSceneProjectionRanged * gbufferModelView);
                mat4 matSceneToShadow = cascadeProjection * shadowModelView * matModelViewProjectionInv;

                GetFrustumMinMax(matSceneToShadow, clipMin[tile], clipMax[tile]);
            #endif
		}
	#endif
}

#if SHADOW_TYPE == 3
	uniform mat4 shadowModelView;
	uniform float near;
	uniform float far;
#endif

varying vec2 texcoord;

#if defined DEBUG_CSM_FRUSTUM && SHADOW_TYPE == 3 && DEBUG_SHADOW_BUFFER != 0
	varying vec3 shadowTileColors[4];
	varying mat4 matShadowToScene[4];

    #ifdef SHADOW_CSM_TIGHTEN
        varying vec3 clipSize[4];
    #else
    	varying vec3 clipMin[4];
    	varying vec3 clipMax[4];
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

	#if SHADOW_TYPE == 3 && defined DEBUG_CSM_FRUSTUM && DEBUG_SHADOW_BUFFER != 0
		//mat4 matShadowModelView = GetShadowModelViewMatrix();

		for (int tile = 0; tile < 4; tile++) {
			vec2 shadowTilePos = GetShadowTilePos(tile);
			shadowTileColors[tile] = GetShadowTileColor(tile);

			float rangeNear = tile > 0 ? GetCascadeDistance(tile - 1) : near;
			float rangeFar = GetCascadeDistance(tile);
			mat4 matSceneProjectionRanged = gbufferProjection;
			SetProjectionRange(matSceneProjectionRanged, rangeNear, rangeFar);

			mat4 matShadowProjection = GetShadowTileProjectionMatrix(tile);
			mat4 matShadowWorldViewProjectionInv = inverse(matShadowProjection * shadowModelView);
			matShadowToScene[tile] = matSceneProjectionRanged * gbufferModelView * matShadowWorldViewProjectionInv;

            #ifdef SHADOW_CSM_TIGHTEN
                clipSize[tile] = GetCascadePaddedFrustumClipBounds(matShadowProjection, -1.5);
            #else
                // project frustum points
                mat4 matModelViewProjectionInv = inverse(matSceneProjectionRanged * gbufferModelView);
                mat4 matSceneToShadow = matShadowProjection * shadowModelView * matModelViewProjectionInv;

                GetFrustumMinMax(matSceneToShadow, clipMin[tile], clipMax[tile]);
            #endif
		}
	#endif
}

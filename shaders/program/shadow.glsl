#extension GL_ARB_gpu_shader5 : enable

#define RENDER_SHADOW

/*
const int shadowtex0Format = R32F;
const int shadowtex1Format = R32F;
*/

const float shadowDistanceRenderMul = 1.0;


varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;

#if SHADOW_TYPE == 3
	flat varying vec2 shadowTilePos;
#endif

#ifdef RENDER_VERTEX
	in vec4 mc_Entity;
	in vec3 vaPosition;
	in vec3 at_midBlock;

	uniform mat4 shadowModelViewInverse;
	uniform float frameTimeCounter;
	uniform vec3 cameraPosition;

    #if MC_VERSION >= 11700
        uniform vec3 chunkOffset;
    #else
        uniform mat4 gbufferModelViewInverse;
    #endif

	#include "/lib/waving.glsl"

	#if SHADOW_TYPE == 3
		uniform int entityId;
		uniform float near;
		uniform float far;

        #ifdef IS_OPTIFINE
            // NOTE: We are using the previous gbuffer matrices cause the current ones don't work in shadow pass
            uniform mat4 gbufferPreviousModelView;
            uniform mat4 gbufferPreviousProjection;
        #else
            uniform mat4 gbufferModelView;
            uniform mat4 gbufferProjection;
        #endif

		#include "/lib/shadows/csm.glsl"
	#elif SHADOW_TYPE != 0
		#include "/lib/shadows/basic.glsl"
	#endif


	void main() {
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
		glcolor = gl_Color;

		#ifdef SHADOW_EXCLUDE_ENTITIES
			if (mc_Entity.x == 0.0) {
				gl_Position = vec4(10.0);

				#if SHADOW_TYPE == 3
					shadowTilePos = vec2(10.0);
				#endif

				return;
			}
		#endif

		#ifdef SHADOW_EXCLUDE_FOLIAGE
			if (mc_Entity.x >= 10000.0 && mc_Entity.x <= 10004.0) {
				gl_Position = vec4(10.0);

				#if SHADOW_TYPE == 3
					shadowTilePos = vec2(10.0);
				#endif
			}
			else {
		#endif

		vec4 pos = gl_Vertex;

		#ifdef ENABLE_WAVING
			if (mc_Entity.x >= 10001.0 && mc_Entity.x <= 10004.0)
				pos.xyz += GetWavingOffset();
		#endif

		#if SHADOW_TYPE == 3
			mat4 matShadowProjections[4];
			PrepareCascadeMatrices(matShadowProjections);

			int shadowTile = GetShadowTile(matShadowProjections);
			shadowTilePos = GetShadowTilePos(shadowTile);
			gl_Position = matShadowProjections[shadowTile] * (gl_ModelViewMatrix * pos);

			gl_Position.xy = gl_Position.xy * 0.5 + 0.5;
			gl_Position.xy = gl_Position.xy * 0.5 + shadowTilePos;
			gl_Position.xy = gl_Position.xy * 2.0 - 1.0;
		#else
			gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * pos);

			#if SHADOW_TYPE == 2
				gl_Position.xyz = distort(gl_Position.xyz);
			#endif
		#endif

		#ifdef SHADOW_EXCLUDE_FOLIAGE
			}
		#endif
	}
#endif

#ifdef RENDER_FRAG
	uniform sampler2D lightmap;
	uniform sampler2D texture;


	void main() {
		#if SHADOW_TYPE == 3
			vec2 p = gl_FragCoord.xy / shadowMapSize - shadowTilePos;
			if (p.x < 0 || p.x >= 0.5 || p.y < 0 || p.y >= 0.5) discard;
		#endif

		vec4 color = texture2D(texture, texcoord) * glcolor;

		gl_FragData[0] = color;
	}
#endif

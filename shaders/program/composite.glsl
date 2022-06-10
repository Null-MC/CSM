#define RENDER_COMPOSITE

#include "/lib/common.glsl"

#if SHADOW_TYPE == 3
	uniform mat4 shadowModelView;
	uniform float near;
	uniform float far;

	#include "/lib/shadows/csm.glsl"
#endif

varying vec2 texcoord;

#if defined DEBUG_CSM_FRUSTUM && SHADOW_TYPE == 3 && DEBUG_SHADOW_BUFFER != 0
	varying vec3 shadowTileColors[4];
	varying mat4 matShadowToScene[4];
#endif

#ifdef RENDER_VERTEX
	#if defined DEBUG_CSM_FRUSTUM && SHADOW_TYPE == 3 && DEBUG_SHADOW_BUFFER != 0
		uniform mat4 gbufferModelView;
		uniform mat4 gbufferProjection;
	#endif

	mat4 GetRangedProjection(mat4 matProj, float zNear, float zFar) {
		matProj[2][2] = -(zFar + zNear) / (zFar - zNear);
		matProj[3][2] = -(2.0 * zFar * zNear) / (zFar - zNear);
		return matProj;
	}


	void main() {
		gl_Position = ftransform();
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

		#if defined DEBUG_CSM_FRUSTUM && SHADOW_TYPE == 3 && DEBUG_SHADOW_BUFFER != 0
			mat4 matShadowWorldView = GetShadowTileViewMatrix();

			for (int i = 0; i < 4; i++) {
				vec2 shadowTilePos = GetShadowTilePos(i);
				shadowTileColors[i] = GetShadowTileColor(i);

				mat4 matShadowProjection = GetShadowTileProjectionMatrix(i, shadowTilePos);

				float rangeNear = i > 0 ? GetCascadeDistance(i - 1) : near;
				float rangeFar = GetCascadeDistance(i);

				// TODO: Alter/create custom matrix with sliced range
				mat4 matSceneProjectionRanged = GetRangedProjection(gbufferProjection, rangeNear, rangeFar);

				mat4 matShadowWorldViewProjectionInv = inverse(matShadowProjection * matShadowWorldView);
				matShadowToScene[i] = matSceneProjectionRanged * gbufferModelView * matShadowWorldViewProjectionInv;
			}
		#endif
	}
#endif

#ifdef RENDER_FRAG
	uniform float frameTimeCounter;

	uniform sampler2D gcolor;
	uniform sampler2D shadowcolor0;
	uniform sampler2D shadowtex0;
	uniform sampler2D shadowtex1;


	void main() {
		#if DEBUG_SHADOW_BUFFER == 1
			vec3 color = texture2D(shadowcolor0, texcoord).rgb;
		#elif DEBUG_SHADOW_BUFFER == 2
			vec3 color = texture2D(shadowtex0, texcoord).rrr;
		#elif DEBUG_SHADOW_BUFFER == 3
			vec3 color = texture2D(shadowtex1, texcoord).rrr;
		#else
			vec3 color = texture2D(gcolor, texcoord).rgb;
		#endif

		#if defined DEBUG_CSM_FRUSTUM && SHADOW_TYPE == 3 && DEBUG_SHADOW_BUFFER != 0
			int tile;
			if (texcoord.y < 0.5) {
				if (texcoord.x < 0.5) {
					tile = 0;
				}
				else {
					tile = 1;
				}
			}
			else {
				if (texcoord.x < 0.5) {
					tile = 2;
				}
				else {
					tile = 3;
				}
			}

			vec3 clipPos;
			clipPos.xy = fract(texcoord * 2.0);
			clipPos.z = texture2D(shadowtex0, texcoord).r;
			clipPos = clipPos * 2.0 - 1.0;

			vec4 sceneClipPos = matShadowToScene[tile] * vec4(clipPos, 1.0);
			sceneClipPos.xyz /= sceneClipPos.w;

			bool contained = true;
			if (sceneClipPos.x < -1.0 || sceneClipPos.x > 1.0) contained = false;
			if (sceneClipPos.y < -1.0 || sceneClipPos.y > 1.0) contained = false;
			if (sceneClipPos.z < -1.0 || sceneClipPos.z > 1.0) contained = false;

			if (contained && clipPos.z < 1.0) {
				color *= vec3(1.0, 0.2, 0.2);
			}
			else {
				#ifdef DEBUG_CASCADE_TINT
					color *= 1.0 - LOD_TINT_FACTOR * (1.0 - shadowTileColors[tile]);
				#endif
			}
		#endif

	/* DRAWBUFFERS:0 */
		gl_FragData[0] = vec4(color, 1.0); //gcolor
	}
#endif

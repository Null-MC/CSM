#define RENDER_COMPOSITE

//#define DEBUG_CSM_FRUSTUM

#include "/lib/common.glsl"

uniform mat4 shadowModelView;
uniform float near;
uniform float far;

#if SHADOW_TYPE == 3
	#include "/lib/shadows/csm.glsl"
#endif

#ifdef RENDER_VERTEX
	out vec2 texcoord;

	#if defined DEBUG_CSM_FRUSTUM && SHADOW_TYPE == 3 && DEBUG_SHADOW_BUFFER != 0
		uniform mat4 gbufferModelView;
		//uniform mat4 gbufferModelViewInverse;
		uniform mat4 gbufferProjection;
		//uniform mat4 gbufferProjectionInverse;

		//out vec3 frustumPos1[8];
		//out vec3 frustumPos2[8];
		//out vec3 frustumPos3[8];
		//out vec3 frustumPos4[8];

		out vec3 shadowTileColors[4];
		out mat4 matShadowToScene[4];
	#endif

	// void GetFrustumPoints(out vec3 pos[8], const in float zMin, const in float zMax) {
	// 	pos[0] = vec3(-1.0, -1.0, zMin);
	// 	pos[1] = vec3( 1.0, -1.0, zMin);
	// 	pos[2] = vec3(-1.0,  1.0, zMin);
	// 	pos[3] = vec3( 1.0,  1.0, zMin);
	// 	pos[4] = vec3(-1.0, -1.0, zMax);
	// 	pos[5] = vec3( 1.0, -1.0, zMax);
	// 	pos[6] = vec3(-1.0,  1.0, zMax);
	// 	pos[7] = vec3( 1.0,  1.0, zMax);

	// 	for (int i = 0; i < 8; i++) {
	// 		vec4 worldPos = gbufferModelViewInverse * (gbufferProjectionInverse * vec4(pos[i], 1.0));
	// 		//worldPos *= 1.0 / worldPos.w;
	// 		//pos[i] = (shadowProjection * (shadowModelView * worldPos)).xyz;
	// 		pos[i] = worldPos.xyz * (1.0 / worldPos.w);
	// 	}
	// }


	void main() {
		gl_Position = ftransform();
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

		#if DEBUG_SHADOW_BUFFER != 0
			texcoord.y = 1.0 - texcoord.y;
		#endif

		#if defined DEBUG_CSM_FRUSTUM && SHADOW_TYPE == 3 && DEBUG_SHADOW_BUFFER != 0
			// TODO: get camera frustum bounds
			//GetFrustumPoints(frustumPos1, -1.0, 1.0);
			//GetFrustumPoints(frustumPos2, -1.0, 1.0);
			//GetFrustumPoints(frustumPos3, -1.0, 1.0);
			//GetFrustumPoints(frustumPos4, -1.0, 1.0);

			mat4 sceneWorldViewProjection = gbufferProjection * gbufferModelView;
			mat4 matShadowWorldView = GetShadowTileViewMatrix();

			for (int i = 0; i < 4; i++) {
				vec2 shadowTilePos = GetShadowTilePos(i);
				shadowTileColors[i] = GetShadowTileColor(i);

				mat4 matShadowProjection = GetShadowTileProjectionMatrix(i, shadowTilePos);

				mat4 shit = transpose(matShadowProjection) * transpose(matShadowWorldView);
				matShadowToScene[i] = sceneWorldViewProjection * shit;
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

	in vec2 texcoord;

	#if defined DEBUG_CSM_FRUSTUM && SHADOW_TYPE == 3 && DEBUG_SHADOW_BUFFER != 0
		//in vec3 frustumPos1[8];
		//in vec3 frustumPos2[8];
		//in vec3 frustumPos3[8];
		//in vec3 frustumPos4[8];

		in vec3 shadowTileColors[4];
		in mat4 matShadowToScene[4];
	#endif


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
			//vec3 frustumPos[8];
			if (texcoord.y < 0.5) {
				if (texcoord.x < 0.5) {
					tile = 0;
					//frustumPos = frustumPos1;
				}
				else {
					tile = 1;
					//frustumPos = frustumPos2;
				}
			}
			else {
				if (texcoord.x < 0.5) {
					tile = 2;
					//frustumPos = frustumPos3;
				}
				else {
					tile = 3;
					//frustumPos = frustumPos4;
				}
			}

			//vec2 shadowTilePos = GetShadowTilePos(tile);

			vec3 worldPos;
			worldPos.xy = fract(texcoord * 2.0);
			worldPos.z = texture2D(shadowtex0, texcoord).r;
			worldPos.y = 1.0 - worldPos.y;

			worldPos = worldPos * 2.0 - 1.0;

			//worldPos = (matShadowWorldViewProjectionInv[tile] * vec4(worldPos, 1.0)).xyz;

			vec4 p = matShadowToScene[tile] * vec4(worldPos, 1.0);
			vec3 scenePos = p.xyz;// / p.w;

			bool contained = true;
			if (scenePos.x < -1.0 || scenePos.x > 1.0) contained = false;
			if (scenePos.y < -1.0 || scenePos.y > 1.0) contained = false;
			if (scenePos.z < -1.0 || scenePos.z > 1.0) contained = false;

			if (contained) {
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

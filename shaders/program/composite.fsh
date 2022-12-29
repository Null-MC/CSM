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
		if (texcoord.y < 0.5)
			tile = texcoord.x < 0.5 ? 0 : 1;
		else
			tile = texcoord.x < 0.5 ? 2 : 3;

		vec3 clipPos;
		clipPos.xy = fract(texcoord * 2.0);
		clipPos.z = texture2D(shadowtex0, texcoord).r;
		clipPos = clipPos * 2.0 - 1.0;

		vec4 sceneClipPos = matShadowToScene[tile] * vec4(clipPos, 1.0);
		sceneClipPos.xyz /= sceneClipPos.w;

		bool frustum_contained = sceneClipPos.x >= -1.0 && sceneClipPos.x <= 1.0
		                      && sceneClipPos.y >= -1.0 && sceneClipPos.y <= 1.0
		                      && sceneClipPos.z >= -1.0 && sceneClipPos.z <= 1.0;

        #ifdef SHADOW_CSM_TIGHTEN
            bool bounds_contained = clipPos.x > -clipSize[tile].x && clipPos.x < clipSize[tile].x
                                 && clipPos.y > -clipSize[tile].y && clipPos.y < clipSize[tile].y;
        #else
            bool bounds_contained = clipPos.x > clipMin[tile].x && clipPos.x < clipMax[tile].x
			                     && clipPos.y > clipMin[tile].y && clipPos.y < clipMax[tile].y;
        #endif

		if (frustum_contained && clipPos.z < 1.0) {
			color *= vec3(1.0, 0.2, 0.2);
		}
		else if (bounds_contained) {
			color *= vec3(1.0, 1.0, 0.2);
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

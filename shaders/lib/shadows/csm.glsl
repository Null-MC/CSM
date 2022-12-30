const float tile_dist[4] = float[](5, 12, 30, 80);

const vec3 _shadowTileColors[4] = vec3[](
	vec3(1.0, 0.0, 0.0),
	vec3(0.0, 1.0, 0.0),
	vec3(0.0, 0.0, 1.0),
	vec3(1.0, 0.0, 1.0));

// tile: 0-3
vec2 GetShadowTilePos(const in int tile) {
    if (tile < 0) return vec2(10.0);

	vec2 pos;
	pos.x = fract(tile / 2.0);
	pos.y = floor(float(tile) * 0.5) * 0.5;
	return pos;
}

// tile: 0-3
vec3 GetShadowTileColor(const in int tile) {
	if (tile < 0) return vec3(1.0);
	return _shadowTileColors[tile];
}

#if defined RENDER_VERTEX || defined RENDER_GEOMETRY
	// tile: 0-3
	float GetCascadeDistance(const in int tile) {
		#ifdef SHADOW_CSM_FITRANGE
			float maxDist = min(shadowDistance, far * SHADOW_CSM_FIT_FARSCALE);

			if (tile == 2) {
				return tile_dist[2] + max(maxDist - tile_dist[2], 0.0) * SHADOW_CSM_FITSCALE;
			}
			else if (tile == 3) {
				return maxDist;
			}
		#endif

		return tile_dist[tile];
	}

	void SetProjectionRange(inout mat4 matProj, const in float zNear, const in float zFar) {
		matProj[2][2] = -(zFar + zNear) / (zFar - zNear);
		matProj[3][2] = -(2.0 * zFar * zNear) / (zFar - zNear);
	}

	// size: in world-space units
	mat4 BuildOrthoProjectionMatrix(const in float width, const in float height, const in float zNear, const in float zFar) {
		return mat4(
		    vec4(2.0 / width, 0.0, 0.0, 0.0),
		    vec4(0.0, 2.0 / height, 0.0, 0.0),
		    vec4(0.0, 0.0, -2.0 / (zFar - zNear), 0.0),
		    vec4(0.0, 0.0, -(zFar + zNear)/(zFar - zNear), 1.0));
	}

	mat4 BuildTranslationMatrix(const in vec3 delta) {
	    return mat4(
	        vec4(1.0, 0.0, 0.0, 0.0),
	        vec4(0.0, 1.0, 0.0, 0.0),
	        vec4(0.0, 0.0, 1.0, 0.0),
	        vec4(delta, 1.0));
	}

	mat4 BuildScalingMatrix(const in vec3 scale) {
	    return mat4(
	        vec4(scale.x, 0.0, 0.0, 0.0),
	        vec4(0.0, scale.y, 0.0, 0.0),
	        vec4(0.0, 0.0, scale.z, 0.0),
	        vec4(0.0, 0.0, 0.0, 1.0));
	}

	#if defined SHADOW_CSM_TIGHTEN || defined DEBUG_CSM_FRUSTUM
		void GetFrustumMinMax(const in mat4 matProjection, out vec3 clipMin, out vec3 clipMax) {
			vec3 frustum[8] = vec3[](
				vec3(-1.0, -1.0, -1.0),
				vec3( 1.0, -1.0, -1.0),
				vec3(-1.0,  1.0, -1.0),
				vec3( 1.0,  1.0, -1.0),
				vec3(-1.0, -1.0,  1.0),
				vec3( 1.0, -1.0,  1.0),
				vec3(-1.0,  1.0,  1.0),
				vec3( 1.0,  1.0,  1.0));

			for (int i = 0; i < 8; i++) {
				vec3 shadowClipPos = unproject(matProjection * vec4(frustum[i], 1.0));

				if (i == 0) {
					clipMin = shadowClipPos;
					clipMax = shadowClipPos;
				}
				else {
					clipMin = min(clipMin, shadowClipPos);
					clipMax = max(clipMax, shadowClipPos);
				}
			}
		}
        
        vec3 GetCascadePaddedFrustumClipBounds(const in mat4 matShadowProjection, const in float padding) {
            return 1.0 + padding * vec3(
                matShadowProjection[0].x,
                matShadowProjection[1].y,
               -matShadowProjection[2].z);
        }

        bool CascadeContainsPosition(const in vec3 shadowViewPos, const in mat4 matShadowProjection) {
            vec3 clipPos = (matShadowProjection * vec4(shadowViewPos, 1.0)).xyz;
            vec3 paddedSize = GetCascadePaddedFrustumClipBounds(matShadowProjection, -1.5);

            return clipPos.x > -paddedSize.x && clipPos.x < paddedSize.x
                && clipPos.y > -paddedSize.y && clipPos.y < paddedSize.y
                && clipPos.z > -paddedSize.z && clipPos.z < paddedSize.z;
        }

        bool CascadeIntersectsPosition(const in vec3 shadowViewPos, const in mat4 matShadowProjection) {
            vec3 clipPos = (matShadowProjection * vec4(shadowViewPos, 1.0)).xyz;
            vec3 paddedSize = GetCascadePaddedFrustumClipBounds(matShadowProjection, 1.5);

            return clipPos.x > -paddedSize.x && clipPos.x < paddedSize.x
                && clipPos.y > -paddedSize.y && clipPos.y < paddedSize.y
                && clipPos.z > -paddedSize.z && clipPos.z < paddedSize.z;
        }
	#endif

	mat4 GetShadowTileProjectionMatrix(const in int tile) {
		float tileSize = GetCascadeDistance(tile);
		float cascadeSize = tileSize * 2.0 + 3.0;

		float zNear = -far;
		float zFar = far * 2.0;

		// TESTING: reduce the depth-range for the nearest cascade only
		//if (tile == 0) zNear = 0.0;

		mat4 matShadowProjection = BuildOrthoProjectionMatrix(cascadeSize, cascadeSize, zNear, zFar);

		#ifdef SHADOW_CSM_TIGHTEN
            #ifdef IS_OPTIFINE
				mat4 matSceneProjectionRanged = gbufferPreviousProjection;
				mat4 matSceneModelView = gbufferPreviousModelView;
            #else
                mat4 matSceneProjectionRanged = gbufferProjection;
                mat4 matSceneModelView = gbufferModelView;
            #endif
			
			// project scene view frustum slices to shadow-view space and compute min/max XY bounds
			float rangeNear = tile > 0 ? GetCascadeDistance(tile - 1) : near;

			rangeNear = max(rangeNear - 3.0, near);
			float rangeFar = tileSize + 3.0;

			SetProjectionRange(matSceneProjectionRanged, rangeNear, rangeFar);

			mat4 matModelViewProjectionInv = inverse(matSceneProjectionRanged * matSceneModelView);
			mat4 matSceneToShadow = matShadowProjection * (shadowModelView * matModelViewProjectionInv);

			vec3 clipMin, clipMax;
			GetFrustumMinMax(matSceneToShadow, clipMin, clipMax);

			// add block padding to clip min/max
			vec2 blockPadding = 3.0 * vec2(
				matShadowProjection[0][0],
				matShadowProjection[1][1]);

			clipMin.xy -= blockPadding;
			clipMax.xy += blockPadding;

			clipMin = max(clipMin, vec3(-1.0));
			clipMax = min(clipMax, vec3( 1.0));

			// offset & scale frustum clip bounds to fullsize
			vec2 center = (clipMin.xy + clipMax.xy) * 0.5;
			vec2 scale = 2.0 / (clipMax.xy - clipMin.xy);
			mat4 matProjScale = BuildScalingMatrix(vec3(scale, 1.0));
			mat4 matProjTranslate = BuildTranslationMatrix(vec3(-center, 0.0));
			matShadowProjection = matProjScale * (matProjTranslate * matShadowProjection);
		#endif

		return matShadowProjection;
	}
#endif

#if (defined RENDER_VERTEX || defined RENDER_GEOMETRY) && !defined RENDER_COMPOSITE
	// returns: tile [0-3] or -1 if excluded
	int GetShadowTile(const in mat4 matShadowProjections[4], const in vec3 blockPos) {
		#ifdef SHADOW_CSM_FITRANGE
			const int max = 3;
		#else
			const int max = 4;
		#endif

		for (int i = 0; i < max; i++) {
			#ifdef SHADOW_CSM_TIGHTEN
                if (CascadeContainsPosition(blockPos, matShadowProjections[i])) return i;
			#else
				float size = GetCascadeDistance(i);
				if (blockPos.xy == clamp(blockPos.xy, -size, size)) return i;
			#endif
		}

		#ifdef SHADOW_CSM_FITRANGE
			return 3;
		#else
			return -1;
		#endif
	}
#endif

#if defined RENDER_VERTEX && !defined RENDER_COMPOSITE
    void ApplyShadows(const in vec4 viewPos) {
        #ifndef RENDER_TEXTURED
            shadowTileColor = vec3(1.0);
        #endif

        if (geoNoL > 0.0) {
            mat4 matViewToShadowView = shadowModelView * gbufferModelViewInverse;

            #if defined RENDER_ENTITIES || defined RENDER_HAND
                vec3 blockPos = vec3(0.0);
            #elif defined RENDER_TEXTURED
                vec3 blockPos = gl_Vertex.xyz;
                blockPos = floor(blockPos + 0.5);
                blockPos = (shadowModelView * vec4(blockPos, 1.0)).xyz;
            #else
                #if MC_VERSION >= 11700 && defined IS_OPTIFINE
                    vec3 blockPos = floor(vaPosition + chunkOffset + at_midBlock / 64.0 + fract(cameraPosition));

                    #if defined RENDER_TERRAIN
                        blockPos = (shadowModelView * vec4(blockPos, 1.0)).xyz;
                    #endif
                #else
                    vec3 blockPos = floor(gl_Vertex.xyz + at_midBlock / 64.0 + fract(cameraPosition));
                    blockPos = (gl_ModelViewMatrix * vec4(blockPos, 1.0)).xyz;
                    blockPos = (matViewToShadowView * vec4(blockPos, 1.0)).xyz;
                #endif
            #endif

            // vertex is facing towards the sun
            mat4 matShadowProjection[4];
            // matShadowProjection[0] = GetShadowTileProjectionMatrix(0);
            // matShadowProjection[1] = GetShadowTileProjectionMatrix(1);
            // matShadowProjection[2] = GetShadowTileProjectionMatrix(2);
            // matShadowProjection[3] = GetShadowTileProjectionMatrix(3);

            // vec3 shadowPos[4];
            for (int i = 0; i < 4; i++) {
	            matShadowProjection[i] = GetShadowTileProjectionMatrix(i);

                shadowProjectionSize[i] = 2.0 / vec2(
                    matShadowProjection[i][0].x,
                    matShadowProjection[i][1].y);

            //     cascadeSize[i] = GetCascadeDistance(i);
                
            //     if (CascadeContainsPosition(shadowViewPos, matShadowProjection[i])) {
            //     	// TODO
            //     }

            //     // convert to shadow screen space
            //     #ifdef RENDER_TEXTURED
            //         shadowPos[i] = (matShadowProjection[i] * shadowViewPos).xyz;
            //     #else
            //         shadowPos[i] = matShadowProjection[i] * shadowViewPos;
            //     #endif

            //     vec2 shadowTilePos = GetShadowTilePos(i);
            //     shadowPos[i].xyz = shadowPos[i].xyz * 0.5 + 0.5; // convert from -1 ~ +1 to 0 ~ 1
            //     shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowTilePos; // scale and translate to quadrant
            }

            shadowTile = GetShadowTile(matShadowProjection, blockPos);

            #if defined DEBUG_CASCADE_TINT && !defined RENDER_TEXTURED
                shadowTileColor = GetShadowTileColor(shadowTile);
            #endif

            vec3 shadowViewPos = (matViewToShadowView * viewPos).xyz;
            shadowPos = (matShadowProjection[shadowTile] * vec4(shadowViewPos, 1.0)).xyz;

            vec2 shadowTilePos = GetShadowTilePos(shadowTile);
            shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5; // convert from -1 ~ +1 to 0 ~ 1
            shadowPos.xy = shadowPos.xy * 0.5 + shadowTilePos; // scale and translate to quadrant
        }
        else {
            // vertex is facing away from the sun
            // mark that this vertex does not need to check the shadow map.
            shadowTile = -1;
            shadowPos = vec3(0.0);
        }
    }
#endif

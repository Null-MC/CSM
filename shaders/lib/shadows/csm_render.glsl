#extension GL_ARB_texture_gather : enable

varying float cascadeSize[4];
flat varying int shadowTile;

const float tile_dist_bias_factor = 0.012288;

#ifdef RENDER_VERTEX
	void ApplyShadows(const in vec4 viewPos) {
		#ifndef RENDER_TEXTURED
			shadowTileColor = vec3(1.0);
		#endif

		if (geoNoL > 0.0) {
			// vertex is facing towards the sun
			mat4 matShadowProjection[4];
			matShadowProjection[0] = GetShadowTileProjectionMatrix(0);
			matShadowProjection[1] = GetShadowTileProjectionMatrix(1);
			matShadowProjection[2] = GetShadowTileProjectionMatrix(2);
			matShadowProjection[3] = GetShadowTileProjectionMatrix(3);

			mat4 matViewToShadowView = shadowModelView * gbufferModelViewInverse;

			vec4 shadowViewPos = matViewToShadowView * viewPos;

			for (int i = 0; i < 4; i++) {
				shadowProjectionSize[i] = 2.0 / vec2(
					matShadowProjection[i][0].x,
					matShadowProjection[i][1].y);

				cascadeSize[i] = GetCascadeDistance(i);
				
				// convert to shadow screen space
				#ifdef RENDER_TEXTURED
					shadowPos[i] = (matShadowProjection[i] * shadowViewPos).xyz;
				#else
					shadowPos[i] = matShadowProjection[i] * shadowViewPos;
				#endif

				vec2 shadowTilePos = GetShadowTilePos(i);
				shadowPos[i].xyz = shadowPos[i].xyz * 0.5 + 0.5; // convert from -1 ~ +1 to 0 ~ 1
				shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowTilePos; // scale and translate to quadrant
			}

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

			shadowTile = GetShadowTile(matShadowProjection, blockPos);

			#if defined DEBUG_CASCADE_TINT && !defined RENDER_TEXTURED
				shadowTileColor = GetShadowTileColor(shadowTile);
			#endif
		}
		else {
			// vertex is facing away from the sun
			// mark that this vertex does not need to check the shadow map.
			shadowTile = -1;

			#ifdef RENDER_TEXTURED
				shadowPos[0] = vec3(0.0);
				shadowPos[1] = vec3(0.0);
				shadowPos[2] = vec3(0.0);
				shadowPos[3] = vec3(0.0);
			#else
				shadowPos[0] = vec4(0.0);
				shadowPos[1] = vec4(0.0);
				shadowPos[2] = vec4(0.0);
				shadowPos[3] = vec4(0.0);
			#endif
		}
	}
#endif

#ifdef RENDER_FRAG
	#define PCF_MAX_RADIUS 0.16

	const int pcf_sizes[4] = int[](4, 3, 2, 1);
	const int pcf_max = 4;

	float SampleDepth(const in vec2 offset, const in int tile) {
		#if SHADOW_COLORS == 0
			return texture2D(shadowtex0, shadowPos[tile].xy + offset).r;
		#else
			return texture2D(shadowtex1, shadowPos[tile].xy + offset).r;
		#endif
	}

	float GetNearestDepth(const in vec2 blockOffset, out int tile) {
		tile = -1;
		for (int i = 0; i < 4 && tile < 0; i++) {
			vec2 shadowTilePos = GetShadowTilePos(i);
			if (clamp(shadowPos[i].xy, shadowTilePos, shadowTilePos + 0.5) == shadowPos[i].xy) tile = i;
		}

		if (tile < 0) return 1.0;

		float shadowResScale = tile_dist_bias_factor * shadowPixelSize;
		float texSize = shadowMapSize * 0.5;

		vec2 pixelPerBlockScale = (texSize / shadowProjectionSize[tile]) * shadowPixelSize;
		
		vec2 pixelOffset = blockOffset * pixelPerBlockScale;

		float bias = 0.0001;//cascadeSize[tile] * shadowResScale * SHADOW_BIAS_SCALE;
		// TODO: BIAS NEEDS TO BE BASED ON DISTANCE
		// In theory that should help soften the transition between cascades

		// TESTING: reduce the depth-range for the nearest cascade only
		//if (i == 0) bias *= 0.5;

		// if (texDepth < shadowPos[i].z - min(bias / geoNoL, 0.1) && texDepth < depth) {
		// 	depth = texDepth;
		// 	tile = i;
		// }

		return SampleDepth(pixelOffset, tile) + bias;
	}

    vec2 GetPixelRadius(const in vec2 blockRadius) {
        float texSize = shadowMapSize * 0.5;
        return blockRadius * (texSize / shadowProjectionSize[shadowTile]) * shadowPixelSize;
    }

    #ifdef SHADOW_ENABLE_HWCOMP
        // returns: [0] when depth occluded, [1] otherwise
        float CompareDepth(const in vec2 offset, const in float bias, const in int tile) {
            return shadow2D(shadow, shadowPos[tile].xyz + vec3(offset, -bias)).r;
        }

        // returns: [0] when depth occluded, [1] otherwise
        float CompareNearestDepth(const in vec2 blockOffset, out int tile) {
            vec2 pixelPerBlockScale = (cascadeTexSize / shadowProjectionSize[tile]) * shadowPixelSize;
            vec2 pixelOffset = blockOffset * pixelPerBlockScale;

			tile = -1;
            for (int i = 0; i < 4 && tile < 0; i++) {
                // Ignore if outside tile bounds
                vec2 shadowTilePos = GetShadowTilePos(i);
				if (clamp(shadowPos[i].xy, shadowTilePos, shadowTilePos + 0.5) == shadowPos[i].xy) tile = i;
            }

			if (tile < 0) return 1.0;

            float cascadeTexSize = shadowMapSize * 0.5;
            float blocksPerPixelScale = max(shadowProjectionSize[tile].x, shadowProjectionSize[tile].y) / cascadeTexSize;

            float zRangeBias = 0.0000001;
            float xySizeBias = blocksPerPixelScale * tile_dist_bias_factor;
            float bias = mix(xySizeBias, zRangeBias, geoNoL) * SHADOW_BIAS_SCALE;

            //vec2 pixelPerBlockScale = (cascadeTexSize / shadowProjectionSize[tile]) * shadowPixelSize;
            //vec2 pixelOffset = blockOffset * pixelPerBlockScale;

            return CompareDepth(pixelOffset, bias, tile);
        }
    #endif

    #if SHADOW_FILTER != 0
    	int GetShadowCascade(const in float blockRadius) {
            for (int i = 0; i < 4; i++) {
	            vec2 padding = vec2(0.0);//blockRadius / shadowProjectionSize[tile];

                // Ignore if outside tile bounds
                vec2 shadowTilePos = GetShadowTilePos(i);
                vec2 clipMin = shadowTilePos + padding;
                vec2 clipMax = shadowTilePos + 0.5 - padding;

				if (clamp(shadowPos[i].xy, clipMin, clipMax) == shadowPos[i].xy) return i;
            }

			return -1;
    	}

        float GetShadowing_PCF(const in float blockRadius, const in int sampleCount, const in int tile) {
            float cascadeTexSize = shadowMapSize * 0.5;
            vec2 pixelPerBlockScale = (cascadeTexSize / shadowProjectionSize[tile]) * shadowPixelSize;

            float shadow = 0.0;
            for (int i = 0; i < sampleCount; i++) {
                vec2 blockOffset = (hash23(vec3(gl_FragCoord.xy, i))*2.0 - 1.0) * blockRadius;
	            vec2 pixelOffset = blockOffset * pixelPerBlockScale;

                #ifdef SHADOW_ENABLE_HWCOMP
	                shadow += 1.0 - CompareDepth(pixelOffset, tile);
	            #else
                    float texDepth = SampleDepth(pixelOffset, tile);
                    shadow += step(texDepth + EPSILON, shadowPos[tile].z);
	            #endif
            }

            return shadow / sampleCount;
            //return smoothstep(0.0, 1.0, shadow / sampleCount);
        }
    #endif

	#if SHADOW_COLORS == 1
		vec3 GetShadowColor() {
			int tile = -1;
			float depthLast = 1.0;
			for (int i = 0; i < 4; i++) {
				vec2 shadowTilePos = GetShadowTilePos(i);
				if (shadowPos[i].x < shadowTilePos.x || shadowPos[i].x > shadowTilePos.x + 0.5) continue;
				if (shadowPos[i].y < shadowTilePos.y || shadowPos[i].y > shadowTilePos.y + 0.5) continue;

				//when colored shadows are enabled and there's nothing OPAQUE between us and the sun,
				//perform a 2nd check to see if there's anything translucent between us and the sun.
				float depth = texture2D(shadowtex0, shadowPos[i].xy).r;
				if (depth + EPSILON < 1.0 && depth < shadowPos[i].z && depth < depthLast) {
					depthLast = depth;
					tile = i;
				}
			}

			if (tile < 0) return vec3(1.0);

			//surface has translucent object between it and the sun. modify its color.
			//if the block light is high, modify the color less.
			vec4 shadowLightColor = texture2D(shadowcolor0, shadowPos[tile].xy);
			vec3 color = RGBToLinear(shadowLightColor.rgb);

			//make colors more intense when the shadow light color is more opaque.
			return mix(vec3(1.0), color, shadowLightColor.a);
		}
	#endif

	#if SHADOW_FILTER == 2
		// PCF + PCSS
		#define SHADOW_BLOCKER_SAMPLES 12

		float FindBlockerDistance(const in float blockRadius, const in int sampleCount, const in int tile) {
            float cascadeTexSize = shadowMapSize * 0.5;
            vec2 pixelPerBlockScale = (cascadeTexSize / shadowProjectionSize[tile]) * shadowPixelSize;
			
			// NOTE: This optimization doesn't really help here rn since the search radius is fixed
			//if (blockRadius <= shadowPixelSize) sampleCount = 1;

			//float blockRadius = SearchWidth(uvLightSize, shadowPos.z);
			//float blockRadius = 6.0; //SHADOW_LIGHT_SIZE * (shadowPos.z - PCSS_NEAR) / shadowPos.z;
			float avgBlockerDistance = 0;
			int blockers = 0;

			for (int i = 0; i < sampleCount; i++) {
				vec2 blockOffset = (hash23(vec3(gl_FragCoord.xy, i))*2.0 - 1.0) * blockRadius;
	            vec2 pixelOffset = blockOffset * pixelPerBlockScale;

				float texDepth = SampleDepth(pixelOffset, tile);

				if (texDepth < shadowPos[tile].z) { // - directionalLightShadowMapBias
					avgBlockerDistance += texDepth;
					blockers++;
				}
			}

			if (blockers == sampleCount) return 1.0;
			return blockers > 0 ? avgBlockerDistance / blockers : 0.0;
		}

		float GetShadowing() {
			int tile = GetShadowCascade(SHADOW_PCF_SIZE);
			if (tile < 0) return 1.0; // TODO: or 0?

			// blocker search
			int blockerSampleCount = SHADOW_BLOCKER_SAMPLES;
			float blockerDistance = FindBlockerDistance(SHADOW_PCF_SIZE, blockerSampleCount, tile);
			if (blockerDistance <= 0.0) return 1.0;
			if (blockerDistance >= 1.0) return 0.0;

			// penumbra estimation
			float penumbraWidth = (shadowPos[shadowTile].z - blockerDistance) / blockerDistance;

			// percentage-close filtering
			float blockRadius = clamp(penumbraWidth * 75.0, 0.0, 1.0) * SHADOW_PCF_SIZE; // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;

            int pcfSampleCount = SHADOW_PCF_SAMPLES;
			vec2 pixelRadius = GetPixelRadius(vec2(blockRadius));
			if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) pcfSampleCount = 1;

			return 1.0 - GetShadowing_PCF(blockRadius, pcfSampleCount, tile);
		}
	#elif SHADOW_FILTER == 1
		// PCF
		float GetShadowing() {
			int tile = GetShadowCascade(SHADOW_PCF_SIZE);
			if (tile < 0) return 1.0; // TODO: or 0?

			int sampleCount = SHADOW_PCF_SAMPLES;
            vec2 pixelRadius = GetPixelRadius(vec2(SHADOW_PCF_SIZE));
			if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

			return 1.0 - max(GetShadowing_PCF(SHADOW_PCF_SIZE, sampleCount, tile) - 0.5*min(1.0 - geoNoL, 1.0), 0.0);
		}
	#elif SHADOW_FILTER == 0
		// Unfiltered
		float GetShadowing() {
        	int tile;
            #ifdef SHADOW_ENABLE_HWCOMP
                return CompareNearestDepth(vec2(0.0), tile);
            #else
    			float texDepth = GetNearestDepth(vec2(0.0), tile);
    			return step(shadowPos[tile].z, texDepth + EPSILON);
            #endif
		}
	#endif
#endif

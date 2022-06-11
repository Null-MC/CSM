#ifdef RENDER_VERTEX
	const float tile_dist_bias_factor = 0.012288;

	void ApplyShadows(const in vec4 viewPos) {
		#ifndef RENDER_TEXTURED
			shadowTileColor = vec3(1.0);
		#endif

		if (geoNoL > 0.0) { //vertex is facing towards the sun
			vec4 posP = gbufferModelViewInverse * viewPos;
			float shadowResScale = (1.0 / shadowMapResolution) * tile_dist_bias_factor;

			// mat4 matShadowWorldView = GetShadowTileViewMatrix();

			for (int i = 0; i < 4; i++) {
				vec2 shadowTilePos = GetShadowTilePos(i);

				// mat4 matShadowProjection = GetShadowTileProjectionMatrix(i, shadowTilePos);
				mat4 matShadowWorldView, matShadowProjection;
				GetShadowTileModelViewProjectionMatrix(i, matShadowWorldView, matShadowProjection);
				
				shadowPos[i] = (matShadowProjection * (matShadowWorldView * posP)).xyz; // convert to shadow screen space
				shadowPos[i].xyz = shadowPos[i].xyz * 0.5 + 0.5; // convert from -1 ~ +1 to 0 ~ 1
				shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowTilePos; // scale and translate to quadrant

				float size = GetCascadeDistance(i);
				float bias = size * shadowResScale * SHADOW_BIAS_SCALE;

				#if SHADOW_FILTER != 0
					bias *= 3.0;
				#endif

				shadowPos[i].z -= min(bias / geoNoL, 0.1); // apply shadow bias
			}

			vec3 blockPos = GetBlockPos();
			shadowTile = GetShadowTile(blockPos);

			#if defined DEBUG_CASCADE_TINT && !defined RENDER_TEXTURED
				shadowTileColor = GetShadowTileColor(shadowTile);
			#endif
		}
		else { //vertex is facing away from the sun
			// mark that this vertex does not need to check the shadow map.
			shadowPos[0] = vec3(0.0);
			shadowPos[1] = vec3(0.0);
			shadowPos[2] = vec3(0.0);
			shadowPos[3] = vec3(0.0);
		}
	}
#endif

#ifdef RENDER_FRAG
	const int pcf_sizes[4] = int[](5, 2, 1, 0);
	const int pcf_max = 5;

	float GetNearestDepth(const in ivec2 offset, out int tile) {
		float depth = 1.0;
		tile = -1;

		for (int i = 0; i < 4; i++) {
			vec2 shadowTilePos = GetShadowTilePos(i);
			if (shadowPos[i].x < shadowTilePos.x || shadowPos[i].x > shadowTilePos.x + 0.5) continue;
			if (shadowPos[i].y < shadowTilePos.y || shadowPos[i].y > shadowTilePos.y + 0.5) continue;

			vec2 texcoord = shadowPos[i].xy;

			#if SHADOW_FILTER != 0
				if (abs(offset.x) > pcf_sizes[i] || abs(offset.y) > pcf_sizes[i]) continue;

				float shadowPixelSize = (1.0 / shadowMapResolution);
				texcoord += offset * shadowPixelSize;
			#endif

			#if SHADOW_COLORS == 0
				//for normal shadows, only consider the closest thing to the sun,
				//regardless of whether or not it's opaque.
				float texDepth = texture2D(shadowtex0, texcoord).r;
			#else
				//for invisible and colored shadows, first check the closest OPAQUE thing to the sun.
				float texDepth = texture2D(shadowtex1, texcoord).r;
			#endif

			//anyHits = true;
			if (texDepth < shadowPos[i].z && texDepth < depth) {
				depth = texDepth;
				tile = i;
			}
		}

		return depth;
	}

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
					//break;
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
		float GetShadowing() {
			// TODO
		}
	#elif SHADOW_FILTER == 1
		// PCF
		float GetShadowing() {
			//vec3 blockPos = GetBlockPos();
			//int expectedTile = GetShadowTile(blockPos);
			if (shadowTile < 0) return 1.0;

			//int radius = pcf_sizes[expectedTile];

			float texDepth;
			//int sampleCount[4] = int[](0, 0, 0, 0);
			//int maxSampleCount = 0;
			float shadow[4] = float[](0.0, 0.0, 0.0, 0.0);
			for (int y = -pcf_max; y <= pcf_max; y++) {
				for (int x = -pcf_max; x <= pcf_max; x++) {
					//bool anyHits;
					int tile;
					ivec2 offset = ivec2(x, y);
					float texDepth = GetNearestDepth(offset, tile);
					//if (anyHits) maxSampleCount++;
					if (texDepth + EPSILON >= 1.0) continue;

					//shadow += shadowPos[i].z > texDepth ? 1.0 : 0.0;
					shadow[tile] += 1.0; //step(texDepth, shadowPos[i].z);
					//sampleCount[tile]++;
				}
			}

			float shadow_final = 0.0;
			for (int i = 0; i < 4; i++) {
				// if (sampleCount[i] > 0)
				// 	shadow_final += shadow[i] / sampleCount[i];
				int size2 = pcf_sizes[i] + 1;
				size2 *= size2;
				shadow_final += shadow[i] / size2 * 0.4;
			}

			// if (sampleCount <= 1 || maxSampleCount <= 1) return 1.0 - shadow;
			// return 1.0 - min(shadow / sampleCount, 1.0);
			//return min(maxSampleCount * 0.01, 1.0);
			//int m = max(sampleCount, maxSampleCount);

			// int t = maxSampleCount - sampleCount;
			// return t * 0.1;

			// if (sampleCount > 1 || maxSampleCount > 1)
			// 	shadow = min(shadow / maxSampleCount, 1.0);

			return max(1.0 - shadow_final, 0.0);
		}
	#elif SHADOW_FILTER == 0
		// Unfiltered
		float GetShadowing() {
			int tile;
			float texDepth = GetNearestDepth(ivec2(0.0), tile);
			return step(1.0, texDepth + EPSILON);
		}
	#endif
#endif

#ifdef RENDER_VERTEX
	const float tile_dist_bias_factor = 0.012288;

	void ApplyShadows(const in vec4 viewPos) {
		#ifndef RENDER_TEXTURED
			shadowTileColor = vec3(1.0);
		#endif

		if (geoNoL > 0.0) { //vertex is facing towards the sun
			vec4 posP = gbufferModelViewInverse * viewPos;
			float shadowResScale = (1.0 / shadowMapResolution) * tile_dist_bias_factor;
			mat4 matShadowModelView = GetShadowModelViewMatrix();

			for (int i = 0; i < 4; i++) {
				vec2 shadowTilePos = GetShadowTilePos(i);
				mat4 matShadowProjection = GetShadowTileProjectionMatrix(i);
				
				#ifdef RENDER_TEXTURED
					shadowPos[i] = (matShadowProjection * (matShadowModelView * posP)).xyz; // convert to shadow screen space
				#else
					shadowPos[i] = matShadowProjection * (matShadowModelView * posP); // convert to shadow screen space
				#endif

				shadowPos[i].xyz = shadowPos[i].xyz * 0.5 + 0.5; // convert from -1 ~ +1 to 0 ~ 1
				shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowTilePos; // scale and translate to quadrant

				float size = GetCascadeDistance(i);
				float bias = size * shadowResScale * SHADOW_BIAS_SCALE;
				// TODO: BIAS NEEDS TO BE BASED ON DISTANCE
				// In theory that should help soften the transition between cascades

				// #if SHADOW_FILTER != 0
				// 	bias *= 3.0;
				// #endif

				shadowPos[i].z -= min(bias / geoNoL, 0.1); // apply shadow bias
			}

			#if defined DEBUG_CASCADE_TINT && !defined RENDER_TEXTURED
				vec3 blockPos = GetBlockPos();
				int shadowTile = GetShadowTile(blockPos);
				shadowTileColor = GetShadowTileColor(shadowTile);
			#endif
		}
		else { //vertex is facing away from the sun
			// mark that this vertex does not need to check the shadow map.
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
	const int pcf_sizes[4] = int[](4, 3, 2, 1);
	const int pcf_max = 4;

	float SampleDepth(const in int tile, const in vec2 offset) {
		#if SHADOW_COLORS == 0
			//for normal shadows, only consider the closest thing to the sun,
			//regardless of whether or not it's opaque.
			#ifdef RENDER_TEXTURED
				return texture2D(shadowtex0, shadowPos[tile].xy + offset).r;
			#else
				return texture2DProj(shadowtex0, vec4(shadowPos[tile].xy + offset * shadowPos[tile].w, shadowPos[tile].z, shadowPos[tile].w)).r;
			#endif
		#else
			//for invisible and colored shadows, first check the closest OPAQUE thing to the sun.
			#ifdef RENDER_TEXTURED
				return texture2D(shadowtex1, shadowPos[tile].xy + offset).r;
			#else
				return texture2DProj(shadowtex1, vec4(shadowPos[tile].xy + offset * shadowPos[tile].w, shadowPos[tile].z, shadowPos[tile].w)).r;
			#endif
		#endif
	}

	// float GetNearestDepth(const in ivec2 offset, out int tile) {
	// 	float depth = 1.0;
	// 	tile = -1;

	// 	for (int i = 0; i < 4; i++) {
	// 		vec2 shadowTilePos = GetShadowTilePos(i);
	// 		if (shadowPos[i].x < shadowTilePos.x || shadowPos[i].x > shadowTilePos.x + 0.5) continue;
	// 		if (shadowPos[i].y < shadowTilePos.y || shadowPos[i].y > shadowTilePos.y + 0.5) continue;

	// 		float bias = 0.0;

	// 		#if SHADOW_FILTER != 0
	// 			if (abs(offset.x) > pcf_sizes[i] || abs(offset.y) > pcf_sizes[i]) continue;

	// 			float shadowPixelSize = (1.0 / shadowMapResolution);

	// 			bias = min(0.00002 * pcf_sizes[i] / geoNoL, 0.1);
	// 		#endif

	// 		float texDepth = SampleDepth(i, offset * shadowPixelSize);

	// 		if (texDepth < shadowPos[i].z - bias && texDepth < depth) {
	// 			depth = texDepth;
	// 			tile = i;
	// 		}
	// 	}

	// 	return depth;
	// }

	float GetNearestDepth(const in vec2 offset, out int tile) {
		float depth = 1.0;
		tile = -1;

		for (int i = 0; i < 4; i++) {
			// Ignore if outside tile bounds
			vec2 shadowTilePos = GetShadowTilePos(i);
			if (shadowPos[i].x < shadowTilePos.x || shadowPos[i].x >= shadowTilePos.x + 0.5) continue;
			if (shadowPos[i].y < shadowTilePos.y || shadowPos[i].y >= shadowTilePos.y + 0.5) continue;

			float texDepth = SampleDepth(i, offset);

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

	#if SHADOW_FILTER != 0
		// float GetShadowing_PCF(const in int radius) {
		// 	float texDepth;
		// 	float shadow[4] = float[](0.0, 0.0, 0.0, 0.0);
		// 	for (int y = -radius; y <= radius; y++) {
		// 		for (int x = -radius; x <= radius; x++) {
		// 			int tile;
		// 			ivec2 offset = ivec2(x, y);
		// 			float texDepth = GetNearestDepth(offset, tile);
		// 			shadow[tile] += step(texDepth + EPSILON, 1.0);
		// 		}
		// 	}

		// 	float shadow_final = 0.0;
		// 	for (int i = 0; i < 4; i++) {
		// 		float size = pcf_sizes[i];
		// 		size = (size + 1.0) * (size + 1.0) + 2.0 * size;// * size2;

		// 		shadow_final += shadow[i] / size;// * 0.5;
		// 	}

		// 	return min(shadow_final, 1.0);
		// }

		float GetShadowing_PCF(float radius) {
			int tile;
			float texDepth;
			float shadow = 0.0;
			for (int i = 0; i < POISSON_SAMPLES; i++) {
				vec2 offset = (poissonDisk[i] / 6.0) * radius;
				float texDepth = GetNearestDepth(offset * shadowPixelSize, tile);

				//if (texDepth + EPSILON >= 1.0) continue;

				//shadow += shadowPos.z > texDepth ? 1.0 : 0.0;
				shadow += step(texDepth + EPSILON, shadowPos[tile].z);
			}

			return shadow / POISSON_SAMPLES;
		}
	#endif

	#if SHADOW_FILTER == 2
		// PCF + PCSS
		#define SHADOW_BLOCKER_SAMPLES 16

		float FindBlockerDistance(float searchWidth) {
			//float searchWidth = SearchWidth(uvLightSize, shadowPos.z);
			//float searchWidth = 6.0; //SHADOW_LIGHT_SIZE * (shadowPos.z - PCSS_NEAR) / shadowPos.z;
			float avgBlockerDistance = 0;
			int blockers = 0;

			int tile;
			for (int i = 0; i < SHADOW_BLOCKER_SAMPLES; i++) {
				vec2 offset = (poissonDisk[i] / 6.0) * searchWidth;
				float texDepth = GetNearestDepth(offset * shadowPixelSize, tile);

				if (texDepth < shadowPos[tile].z) { // - directionalLightShadowMapBias
					avgBlockerDistance += texDepth;
					blockers++;
				}
			}

			return blockers > 0 ? avgBlockerDistance / blockers : -1.0;
		}

		float GetShadowing() {
			// blocker search
			float blockerDistance = FindBlockerDistance(16.0);
			if (blockerDistance < 0.0) return 1.0;

			//return 0.0;

			// penumbra estimation
			// WARNING: IDK WTF to do about the tile index here! so it's 0
			float penumbraWidth = (shadowPos[0].z - blockerDistance) / blockerDistance;

			//return clamp(1.0 - penumbraWidth, 0.0, 1.0);

			// percentage-close filtering
			float uvRadius = clamp(penumbraWidth * 200.0, 0.0, 32.0); // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;
			return 1.0 - GetShadowing_PCF(uvRadius);
		}
	#elif SHADOW_FILTER == 1
		// PCF
		float GetShadowing() {
			return 1.0 - GetShadowing_PCF(6.0);
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

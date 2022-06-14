#extension GL_ARB_texture_gather : enable

flat varying int shadowTile;

#ifdef RENDER_VERTEX
	const float tile_dist_bias_factor = 0.012288;

	void ApplyShadows(const in vec4 viewPos) {
		#ifndef RENDER_TEXTURED
			shadowTileColor = vec3(1.0);
		#endif

		if (geoNoL > 0.0) { //vertex is facing towards the sun
			float shadowResScale = (1.0 / shadowMapResolution) * tile_dist_bias_factor;
			mat4 matShadowModelView = GetShadowModelViewMatrix();

			mat4 matShadowProjection[4];
			PrepareCascadeMatrices(matShadowProjection);

			vec4 shadowViewPos = matShadowModelView * (gbufferModelViewInverse * viewPos);

			for (int i = 0; i < 4; i++) {
				shadowProjectionScale[i] = vec2(
					matShadowProjection[i][0].x,
					matShadowProjection[i][1].y);

				vec2 shadowTilePos = GetShadowTilePos(i);
				
				#ifdef RENDER_TEXTURED
					shadowPos[i] = (matShadowProjection[i] * shadowViewPos).xyz; // convert to shadow screen space
				#else
					shadowPos[i] = matShadowProjection[i] * shadowViewPos; // convert to shadow screen space
				#endif

				shadowPos[i].xyz = shadowPos[i].xyz * 0.5 + 0.5; // convert from -1 ~ +1 to 0 ~ 1
				shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowTilePos; // scale and translate to quadrant

				float size = GetCascadeDistance(i);
				float bias = size * shadowResScale * SHADOW_BIAS_SCALE;
				// TODO: BIAS NEEDS TO BE BASED ON DISTANCE
				// In theory that should help soften the transition between cascades

				// TESTING: reduce the depth-range for the nearest cascade only
				//if (i == 0) bias *= 0.5;

				shadowPos[i].z -= min(bias / geoNoL, 0.1);
			}

			shadowTile = GetShadowTile(matShadowProjection);

			#if defined DEBUG_CASCADE_TINT && !defined RENDER_TEXTURED
				shadowTileColor = GetShadowTileColor(shadowTile);
			#endif
		}
		else { //vertex is facing away from the sun
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

	float SampleDepth4(const in vec2 offset, const in int tile) {
		#if SHADOW_COLORS == 0
			//for normal shadows, only consider the closest thing to the sun,
			//regardless of whether or not it's opaque.
			vec4 samples = textureGather(shadowtex0, shadowPos[tile].xy + offset);
		#else
			//for invisible and colored shadows, first check the closest OPAQUE thing to the sun.
			vec4 samples = textureGather(shadowtex1, shadowPos[tile].xy + offset);
		#endif

		float result = samples[0];
		for (int i = 1; i < 4; i++)
			result = min(result, samples[i]);

		return result;
	}

	// float CompareDepth4(const in vec2 offset, const in flat z, const in int tile) {
	// 	#if SHADOW_COLORS == 0
	// 		vec4 samples = shadowGather(shadowtex0, shadowPos[tile].xy + offset);
	// 	#else
	// 		vec4 samples = shadowGather(shadowtex1, shadowPos[tile].xy + offset);
	// 	#endif

	// 	return step(z, samples);
	// }

	float GetNearestDepth(const in vec2 offset, out int tile) {
		float depth = 1.0;
		tile = -1;

		float texDepth;
		for (int i = 0; i < 4; i++) {
			// Ignore if outside tile bounds
			vec2 shadowTilePos = GetShadowTilePos(i);
			if (shadowPos[i].x < shadowTilePos.x || shadowPos[i].x >= shadowTilePos.x + 0.5) continue;
			if (shadowPos[i].y < shadowTilePos.y || shadowPos[i].y >= shadowTilePos.y + 0.5) continue;

			float texSize = shadowMapResolution * 0.5;
			vec2 viewSize = 2.0 / shadowProjectionScale[i];
			vec2 pixelPerBlockScale = texSize / viewSize * shadowPixelSize;

			//int sampleRadius = exp2(1.0 + max(i - shadowTile, 0.0));
			if (i < shadowTile) {
				// texDepth = 1.0;
				// for (int iy = 0; iy < 2; iy++) {
				// 	for (int ix = 0; ix < 2; ix++) {
				// 		vec2 texcoord = offset * pixelPerBlockScale;
				// 		texcoord.x += (2.0 * ix - 1.0) * shadowPixelSize;
				// 		texcoord.y += (2.0 * iy - 1.0) * shadowPixelSize;

				// 		float d = SampleDepth4(texcoord, i);
				// 		texDepth = min(texDepth, d);
				// 	}
				// }
				texDepth = SampleDepth4(offset * pixelPerBlockScale - shadowPixelSize, i);
			}
			else if (i > shadowTile) {
				texDepth = SampleDepth4(offset * pixelPerBlockScale - shadowPixelSize, i);
			}
			else {
				texDepth = SampleDepth(offset * pixelPerBlockScale, i);
			}

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
		float GetShadowing_PCF(float radius) {
			int tile;
			float texDepth;
			float shadow = 0.0;
			for (int i = 0; i < POISSON_SAMPLES; i++) {
				vec2 offset = GetPoissonOffset(i) * radius;
				float texDepth = GetNearestDepth(offset, tile);
				shadow += step(texDepth + EPSILON, shadowPos[tile].z);
			}

			float s = shadow / POISSON_SAMPLES;

			#if SHADOW_FILTER == 1
				float f = 1.0 - max(geoNoL, 0.0);
				s = clamp(s - 0.8*f, 0.0, 1.0) * (1.0 + 1.0 * f);
			#endif

			return clamp(s, 0.0, 1.0);
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
				vec2 offset = GetPoissonOffset(i) * searchWidth;
				float texDepth = GetNearestDepth(offset, tile);

				if (texDepth < shadowPos[tile].z) { // - directionalLightShadowMapBias
					avgBlockerDistance += texDepth;
					blockers++;
				}
			}

			return blockers > 0 ? avgBlockerDistance / blockers : -1.0;
		}

		float GetShadowing() {
			// blocker search
			float blockerDistance = FindBlockerDistance(0.5 * PCF_MAX_RADIUS);
			if (blockerDistance < 0.0) return 1.0;

			// penumbra estimation
			// WARNING: IDK WTF to do about the tile index here! so it's 0
			float penumbraWidth = (shadowPos[0].z - blockerDistance) / blockerDistance;

			// percentage-close filtering
			float uvRadius = clamp(penumbraWidth * 10.0, 0.0, 1.0); // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;
			return 1.0 - GetShadowing_PCF(uvRadius * PCF_MAX_RADIUS);
		}
	#elif SHADOW_FILTER == 1
		// PCF
		float GetShadowing() {
			return 1.0 - GetShadowing_PCF(0.015);
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

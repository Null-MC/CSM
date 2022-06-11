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
			shadowPos[0] = vec3(0.0);
			shadowPos[1] = vec3(0.0);
			shadowPos[2] = vec3(0.0);
			shadowPos[3] = vec3(0.0);
		}
	}
#endif

#ifdef RENDER_FRAG
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
			float factor = 1.0;

			for (int i = 3; i >= 0; i--) {
				vec2 shadowTilePos = GetShadowTilePos(i);
				if (shadowPos[i].x < shadowTilePos.x || shadowPos[i].x > shadowTilePos.x + 0.5) continue;
				if (shadowPos[i].y < shadowTilePos.y || shadowPos[i].y > shadowTilePos.y + 0.5) continue;

				const int pcf_sizes[4] = int[](5, 3, 2, 1);
				factor = min(factor, 1.0 - PCF(shadowPos[i].xy, shadowPos[i].z, pcf_sizes[i]));
				if (factor < EPSILON) break;
			}

			return max(factor, 0.0);
		}
	#elif SHADOW_FILTER == 0
		// Unfiltered
		float GetShadowing() {
			for (int i = 3; i >= 0; i--) {
				vec2 shadowTilePos = GetShadowTilePos(i);
				if (shadowPos[i].x < shadowTilePos.x || shadowPos[i].x > shadowTilePos.x + 0.5) continue;
				if (shadowPos[i].y < shadowTilePos.y || shadowPos[i].y > shadowTilePos.y + 0.5) continue;

				#if SHADOW_COLORS == 0
					//for normal shadows, only consider the closest thing to the sun,
					//regardless of whether or not it's opaque.
					float depth = texture2D(shadowtex0, shadowPos[i].xy).r;
				#else
					//for invisible and colored shadows, first check the closest OPAQUE thing to the sun.
					float depth = texture2D(shadowtex1, shadowPos[i].xy).r;
				#endif

				if (depth < shadowPos[i].z) return 0.0;
			}

			return 1.0;
		}
	#endif
#endif

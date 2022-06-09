#ifdef RENDER_VERTEX
	const float tile_dist_bias_factor = 0.012288;

	void ApplyShadows(const in vec4 viewPos) {
		#ifdef RENDER_TEXTURED
			geoNoL = 1.0;
		#else
			vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
			vec3 lightDir = normalize(shadowLightPosition);
			geoNoL = dot(lightDir, normal);

			#if defined RENDER_TERRAIN && defined SHADOW_EXCLUDE_FOLIAGE
				//when SHADOW_EXCLUDE_FOLIAGE is enabled, act as if foliage is always facing towards the sun.
				//in other words, don't darken the back side of it unless something else is casting a shadow on it.
				if (mc_Entity.x >= 10000.0 && mc_Entity.x <= 10004.0) geoNoL = 1.0;
			#endif
		#endif

		#ifndef RENDER_TEXTURED
			shadowTileColor = vec3(1.0);
		#endif

		if (geoNoL > 0.0) { //vertex is facing towards the sun
			vec4 posP = gbufferModelViewInverse * viewPos;
			float shadowResScale = (1.0 / shadowMapResolution) * tile_dist_bias_factor;

			mat4 matShadowView = GetShadowTileViewMatrix();

			for (int i = 0; i <= 3; i++) {
				vec2 shadowTilePos = GetShadowTilePos(i);
				mat4 matShadowProj = GetShadowTileProjectionMatrix(i, shadowTilePos);
				
				shadowPos[i] = (matShadowProj * (matShadowView * posP)).xyz; // convert to shadow screen space
				shadowPos[i].xyz = shadowPos[i].xyz * 0.5 + 0.5; // convert from -1 ~ +1 to 0 ~ 1
				shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowTilePos; // scale and translate to quadrant

				float size = tile_dist[i];

				#ifdef SHADOW_CSM_FITWORLD
					if (i == 2) size += max(far * SHADOW_CSM_FIT_FARSCALE - size, 0.0) * SHADOW_CSM_FITSCALE;
					if (i == 3) size = far * SHADOW_CSM_FIT_FARSCALE;
				#endif

				shadowPos[i].z -= size * shadowResScale / clamp(geoNoL, 0.02, 1.0); // apply shadow bias
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
	float GetShadowing(out vec3 color) {
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

			if (depth < shadowPos[i].z) {
				color = vec3(1.0);
				return 0.0;
			}
		}

		color = vec3(1.0);
		#if SHADOW_COLORS == 1
			int i = 3;
			for (; i >= 0; i--) {
				//when colored shadows are enabled and there's nothing OPAQUE between us and the sun,
				//perform a 2nd check to see if there's anything translucent between us and the sun.
				if (texture2D(shadowtex0, shadowPos[i].xy).r > shadowPos[i].z) break;
			}

			if (i >= 0) {
				//surface has translucent object between it and the sun. modify its color.
				//if the block light is high, modify the color less.
				vec4 shadowLightColor = texture2D(shadowcolor0, shadowPos[i].xy);
				color = RGBToLinear(shadowLightColor.rgb);

				//make colors more intense when the shadow light color is more opaque.
				color = mix(vec3(1.0), color, shadowLightColor.a);
			}
		#endif

		return 1.0;
	}
#endif

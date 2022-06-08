// tile: 0-3
vec2 GetShadowTilePos(const in int tile) {
	vec2 pos;
	pos.x = (tile % 2) * 0.5;
	pos.y = floor(float(tile) * 0.5) * 0.5;
	return pos;
}

#ifdef RENDER_VERTEX
	const float tile_scales[4] = float[](0.02, 0.06, 0.3, 1.0);
	const float tile_bias[4] = float[](0.000015, 0.00004, 0.2, 1.0);

	const vec3 shadowTileColors[4] = vec3[](
		vec3(1.0, 0.0, 0.0),
		vec3(0.0, 1.0, 0.0),
		vec3(0.0, 0.0, 1.0),
		vec3(1.0, 0.0, 1.0));

	vec3 GetBlockPos() {
		#ifndef SHADOW_EXCLUDE_ENTITIES
			#if defined RENDER_TERRAIN || defined RENDER_SHADOW
				if (mc_Entity.x == 0.0) return vec3(0.0);
			#elif defined RENDER_ENTITIES
				return vec3(0.0);
			#endif
		#endif

		#ifdef RENDER_SHADOW
			vec3 midBlockPosition = floor(vaPosition + chunkOffset + at_midBlock / 64.0 + fract(cameraPosition));
			vec4 pos = gl_ModelViewMatrix * vec4(midBlockPosition, 1.0);
		#elif defined RENDER_TERRAIN
			vec3 midBlockPosition = floor(vaPosition + chunkOffset + at_midBlock / 64.0 + fract(cameraPosition));
			vec4 pos = shadowModelView * vec4(midBlockPosition, 1.0);
		#else
			vec4 pos = gl_Vertex;
			pos.xyz = floor(pos.xyz + 0.5);
			pos = shadowModelView * pos;
		#endif

		return pos.xyz;
	}

	// returns: tile [0-3]
	int GetShadowTile(const in vec3 blockPos) {
		#ifndef SHADOW_EXCLUDE_ENTITIES
			#if defined RENDER_SHADOW
				if (entityId == CSM_PLAYER_ID) return 0;
				if (mc_Entity.x == 0.0) return SHADOW_ENTITY_CASCADE;
			#elif defined RENDER_TERRAIN
				if (mc_Entity.x == 0.0) return SHADOW_ENTITY_CASCADE;
			#elif defined RENDER_ENTITIES
				if (entityId == CSM_PLAYER_ID) return 0;
				return SHADOW_ENTITY_CASCADE;
			#endif
		#endif

		if (blockPos.x > -5 && blockPos.x < 5
		 && blockPos.y > -5 && blockPos.y < 5) return 0;

		if (blockPos.x > -15 && blockPos.x < 15
		 && blockPos.y > -15 && blockPos.y < 15) return 1;

		float dist = length(blockPos.xy);

		//if (dist < 5.0) return 0;
		//if (dist < 20.0) return 1;

		float distF = dist / far;
		//if (dist < tile_scales[1]) return 1;
		if (distF < tile_scales[2]) return 2;
		return 3;
	}

	// tile: 0-3
	float GetShadowTileScale(const in int tile) {
		return tile_scales[tile];
	}

	// tile: 0-3
	vec3 GetShadowTileColor(const in int tile) {
		return shadowTileColors[tile];
	}

	// tile: 0-3
	mat4 GetShadowTileViewMatrix(const in int tile) {
		#ifdef RENDER_SHADOW
			return gl_ModelViewMatrix;
		#else
			return shadowModelView;
		#endif


		// TODO: Investigate using custom view matrix translation to
		//       improve cascade alignment with camera frustum.

		// vec3 forward = normalize(at - eye);    
		// vec3 side = normalize(cross(forward, up));
		// vec3 up = cross(side, forward);

		// return mat4(
		// 	vec4(side.x, side.y, side.z, -dot(side, eye)),
		// 	vec4(up.x, up.y, up.z, -dot(up, eye)),
		// 	vec4(-forward.x, -forward.y, -forward.z, dot(forward, eye)),
		// 	vec4(0.0, 0.0, 0.0, 1.0));
	}

	// tile: 0-3
	mat4 GetShadowTileProjectionMatrix(const in int tile, const in vec2 tilePos) {
		float size;
		if (tile == 0) size = 10.0;
		else if (tile == 1) size = 30.0;
		else {
			float shadowTileScale = GetShadowTileScale(tile);
			size = far * shadowTileScale * 2.0;
		}

		size += 2;
		float n = near;
		float f = far * 2.0;

		return mat4(
		    vec4(2.0 / size, 0.0, 0.0, 0.0),
		    vec4(0.0, 2.0 / size, 0.0, 0.0),
		    vec4(0.0, 0.0, -2.0 / (f - n), 0.0),
		    vec4(0.0, 0.0, -(f + n)/(f - n), 1.0));
	}

	#ifndef RENDER_SHADOW
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
					if (mc_Entity.x == 10000.0 || mc_Entity.x == 10001.0) geoNoL = 1.0;
				#endif
			#endif

			#ifndef RENDER_TEXTURED
				shadowTileColor = vec3(1.0);
			#endif

			if (geoNoL > 0.0) { //vertex is facing towards the sun
				vec4 posP = gbufferModelViewInverse * viewPos;

				for (int i = 0; i <= 3; i++) {
					vec2 shadowTilePos = GetShadowTilePos(i);
					mat4 matShadowView = GetShadowTileViewMatrix(i);
					mat4 matShadowProj = GetShadowTileProjectionMatrix(i, shadowTilePos);
					float shadowTileScale = GetShadowTileScale(i);
					
					shadowPos[i] = (matShadowProj * (matShadowView * posP)).xyz; //convert to shadow screen space
					shadowPos[i].xyz = shadowPos[i].xyz * 0.5 + 0.5; // convert from -1 ~ +1 to 0 ~ 1
					shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowTilePos; // scale and translate to quadrant

					//apply shadow bias
					float bias = tile_bias[i];
					if (i >= 2) bias = SHADOW_BIAS * shadowTileScale;
					shadowPos[i].z -= bias / clamp(geoNoL, 0.02, 1.0);
				}

				#if defined DEBUG_CASCADE_TINT && !defined RENDER_TEXTURED
					vec3 blockPos = GetBlockPos();
					int shadowTile = GetShadowTile(blockPos);
					shadowTileColor = GetShadowTileColor(shadowTile);
				#endif
			}
			else { //vertex is facing away from the sun
				lmcoord.y *= SHADOW_BRIGHTNESS; //guaranteed to be in shadows. reduce light level immediately.

				// mark that this vertex does not need to check the shadow map.
				vec3 empty = vec3(0.0);
				shadowPos[0] = empty;
				shadowPos[1] = empty;
				shadowPos[2] = empty;
				shadowPos[3] = empty;
			}
		}
	#endif
#endif

#ifdef RENDER_FRAG
	vec3 GetShadowColor(inout vec2 lm) {
		vec3 color = vec3(1.0);
		bool hit = false;

		for (int i = 3; i >= 0 && !hit; i--) {
			vec2 shadowTilePos = GetShadowTilePos(i); // TODO: This only exists in vertex shader!
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

			if (depth < shadowPos[i].z) hit = true;
		}

		if (hit) {
			//surface is in shadows. reduce light level.
			lm.y *= SHADOW_BRIGHTNESS;
		}
		else {
			//surface is in direct sunlight. increase light level.
			#ifdef RENDER_TEXTURED
				lm.y = 31.0 / 32.0;
			#else
				lm.y = mix(31.0 / 32.0 * SHADOW_BRIGHTNESS, 31.0 / 32.0, sqrt(geoNoL));
			#endif

			#if SHADOW_COLORS == 1
				for (int i = 3; i >= 0; i--) {
					//when colored shadows are enabled and there's nothing OPAQUE between us and the sun,
					//perform a 2nd check to see if there's anything translucent between us and the sun.
					if (texture2D(shadowtex0, shadowPos[i].xy).r < shadowPos[i].z) {
						//surface has translucent object between it and the sun. modify its color.
						//if the block light is high, modify the color less.
						vec4 shadowLightColor = texture2D(shadowcolor0, shadowPos[i].xy);

						//make colors more intense when the shadow light color is more opaque.
						shadowLightColor.rgb = mix(vec3(1.0), shadowLightColor.rgb, shadowLightColor.a);

						//also make colors less intense when the block light level is high.
						shadowLightColor.rgb = mix(shadowLightColor.rgb, vec3(1.0), lm.x);

						//apply the color.
						color *= shadowLightColor.rgb;
						break;
					}
				}
			#endif
		}

		return color;
	}
#endif

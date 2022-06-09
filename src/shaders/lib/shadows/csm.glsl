#define SHADOW_CSM_FITSCALE 0.1

const float tile_dist[4] = float[](5, 12, 30, 80);

const vec3 _shadowTileColors[4] = vec3[](
	vec3(1.0, 0.0, 0.0),
	vec3(0.0, 1.0, 0.0),
	vec3(0.0, 0.0, 1.0),
	vec3(1.0, 0.0, 1.0));

// tile: 0-3
vec2 GetShadowTilePos(const in int tile) {
	vec2 pos;
	pos.x = (tile % 2) * 0.5;
	pos.y = floor(float(tile) * 0.5) * 0.5;
	return pos;
}

// tile: 0-3
vec3 GetShadowTileColor(const in int tile) {
	if (tile < 0) return vec3(1.0);
	return _shadowTileColors[tile];
}

#if defined RENDER_VERTEX && !defined RENDER_COMPOSITE
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

	// returns: tile [0-3] or -1 if excluded
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

		#ifdef SHADOW_CSM_FITWORLD
			for (int i = 0; i < 2; i++) {
				if (blockPos.x > -tile_dist[i] && blockPos.x < tile_dist[i]
				 && blockPos.y > -tile_dist[i] && blockPos.y < tile_dist[i]) return i;
			}

			float size = tile_dist[2] + max(far * SHADOW_CSM_FIT_FARSCALE - tile_dist[2], 0.0) * SHADOW_CSM_FITSCALE;
			if (blockPos.x > -size && blockPos.x < size
			 && blockPos.y > -size && blockPos.y < size) return 2;

			return 3;
		#else
			for (int i = 0; i < 4; i++) {
				if (blockPos.x > -tile_dist[i] && blockPos.x < tile_dist[i]
				 && blockPos.y > -tile_dist[i] && blockPos.y < tile_dist[i]) return i;
			}

			return -1;
		#endif
	}
#endif

#ifdef RENDER_VERTEX
	mat4 GetShadowTileViewMatrix() {
		#ifdef RENDER_SHADOW
			return gl_ModelViewMatrix;
		#else
			return shadowModelView;
		#endif
	}

	// tile: 0-3
	// mat4 GetShadowTileViewMatrix(const in int tile) {
	// 	// TODO: Investigate using custom view matrix translation to
	// 	//       improve cascade alignment with camera frustum.

	// 	// vec3 forward = normalize(at - eye);    
	// 	// vec3 side = normalize(cross(forward, up));
	// 	// vec3 up = cross(side, forward);

	// 	// return mat4(
	// 	// 	vec4(side.x, side.y, side.z, -dot(side, eye)),
	// 	// 	vec4(up.x, up.y, up.z, -dot(up, eye)),
	// 	// 	vec4(-forward.x, -forward.y, -forward.z, dot(forward, eye)),
	// 	// 	vec4(0.0, 0.0, 0.0, 1.0));
	// }

	// tile: 0-3
	mat4 GetShadowTileProjectionMatrix(const in int tile, const in vec2 tilePos) {
		float size = tile_dist[tile];

		#ifdef SHADOW_CSM_FITWORLD
			if (tile == 2) size += max(far * SHADOW_CSM_FIT_FARSCALE - size, 0.0) * SHADOW_CSM_FITSCALE;
			if (tile == 3) size = far * SHADOW_CSM_FIT_FARSCALE;
		#endif

		float n = -far;
		float f = far * 2.0;
		size = size * 2.0 + 3.0;

		return mat4(
		    vec4(2.0 / size, 0.0, 0.0, 0.0),
		    vec4(0.0, 2.0 / size, 0.0, 0.0),
		    vec4(0.0, 0.0, -2.0 / (f - n), 0.0),
		    vec4(0.0, 0.0, -(f + n)/(f - n), 1.0));
	}
#endif

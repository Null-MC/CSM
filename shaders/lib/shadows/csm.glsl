#define SHADOW_CSM_FITSCALE 0.1
#define SHADOW_CSM_TIGHTEN

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

#ifdef RENDER_VERTEX
	// tile: 0-3
	float GetCascadeDistance(const in int tile) {
		#ifdef SHADOW_CSM_FITWORLD
			if (tile == 2) {
				return tile_dist[2] + max(far * SHADOW_CSM_FIT_FARSCALE - tile_dist[2], 0.0) * SHADOW_CSM_FITSCALE;
			}
			else if (tile == 3) {
				return far * SHADOW_CSM_FIT_FARSCALE;
			}
		#endif

		return tile_dist[tile];
	}

	void SetProjectionRange(inout mat4 matProj, const in float zNear, const in float zFar) {
		matProj[2][2] = -(zFar + zNear) / (zFar - zNear);
		matProj[3][2] = -(2.0 * zFar * zNear) / (zFar - zNear);
	}
#endif

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

		for (int i = 0; i < 4; i++) {
			float size = GetCascadeDistance(i);
			if (blockPos.x > -size && blockPos.x < size
			 && blockPos.y > -size && blockPos.y < size) return i;
		}

		return -1;
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

	// size: in world-space units
	mat4 BuildOrthoProjectionMatrix(const in float width, const in float height) {
		float n = -far;
		float f = far * 2.0;

		return mat4(
		    vec4(2.0 / width, 0.0, 0.0, 0.0),
		    vec4(0.0, 2.0 / height, 0.0, 0.0),
		    vec4(0.0, 0.0, -2.0 / (f - n), 0.0),
		    vec4(0.0, 0.0, -(f + n)/(f - n), 1.0));
	}

	// tile: 0-3
	mat4 GetShadowTileProjectionMatrix(const in int tile) {
		float size = GetCascadeDistance(tile) * 2.0 + 3.0;
		return BuildOrthoProjectionMatrix(size, size);
	}

	mat4 BuildTranslation(const in vec3 delta)
	{
	    return mat4(
	        vec4(1.0, 0.0, 0.0, 0.0),
	        vec4(0.0, 1.0, 0.0, 0.0),
	        vec4(0.0, 0.0, 1.0, 0.0),
	        vec4(delta, 1.0));
	}

	void GetShadowTileModelViewProjectionMatrix(const in int tile, out mat4 matShadowModelView, out mat4 matShadowProjection) {
		#ifdef RENDER_SHADOW
			matShadowModelView = gl_ModelViewMatrix;
		#else
			matShadowModelView = shadowModelView;
		#endif

		matShadowProjection = GetShadowTileProjectionMatrix(tile);

		#ifdef SHADOW_CSM_TIGHTEN
			// project scene view frustum slices to shadow-view space and compute min/max XY bounds
			float size = GetCascadeDistance(tile);
			float rangeNear = tile > 0 ? GetCascadeDistance(tile - 1) : near;
			mat4 matSceneProjectionRanged = gbufferProjection;
			SetProjectionRange(matSceneProjectionRanged, rangeNear, size);

			//mat4 matShadowModelView = GetShadowTileViewMatrix();
			mat4 matModelViewProjectionInv = inverse(matSceneProjectionRanged * gbufferModelView);
			mat4 matSceneToShadow = matShadowProjection * matShadowModelView * matModelViewProjectionInv;
			//mat4 matSceneToShadow = matShadowModelView * matModelViewProjectionInv;

			vec3 frustum[8] = vec3[](
				vec3(-1.0, -1.0, -1.0),
				vec3( 1.0, -1.0, -1.0),
				vec3(-1.0,  1.0, -1.0),
				vec3( 1.0,  1.0, -1.0),
				vec3(-1.0, -1.0,  1.0),
				vec3( 1.0, -1.0,  1.0),
				vec3(-1.0,  1.0,  1.0),
				vec3( 1.0,  1.0,  1.0));

			vec2 clipMin, clipMax;
			for (int i = 0; i < 8; i++) {
				vec4 shadowClipPos = matSceneToShadow * vec4(frustum[i], 1.0);
				shadowClipPos.xyz /= shadowClipPos.w;

				if (i == 0) {
					clipMin = shadowClipPos.xy;
					clipMax = shadowClipPos.xy;
				}
				else {
					clipMin = min(clipMin, shadowClipPos.xy);
					clipMax = max(clipMax, shadowClipPos.xy);
				}
			}

			// TODO: offset view matrix to min/max center
			//vec2 center = (clipMin + clipMax) * 0.5;
			//matShadowModelView[0][3] = center.x;
			//matShadowModelView[1][3] = center.y;
			//mat4 translate = BuildTranslation(vec3(-center, 0.0) * 0.1);
			//matShadowModelView = translate * matShadowModelView;
			//matShadowProjection = translate * matShadowProjection;

			// update proj matrix min/max bounds
			//float width = clipMax.x - clipMin.x;
			//float height = clipMax.y - clipMin.y;
			//matShadowProjection = BuildOrthoProjectionMatrix(width, height);

			// s = size + 1.5;
			// float l = -s;
			// float r = s;
			// float b = -s;
			// float t = s;

			// // l = max(l, clipMin.x);
			// // r = min(r, clipMax.x);
			// // b = max(b, clipMin.y);
			// //t = max(min(t, clipMax.y), 1.0);
			// t *= 0.5;
			// b *= 0.5;

			// matShadowProj[0][0] = 2.0 / (r - l);
			// matShadowProj[1][1] = 2.0 / (t - b);
			// matShadowProj[0][3] = -((r + l) / (r - l));
			// matShadowProj[1][3] = -((t + b) / (t - b));
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
#endif

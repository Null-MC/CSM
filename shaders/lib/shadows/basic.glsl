//euclidian distance is defined as sqrt(a^2 + b^2 + ...)
//this length function instead does cbrt(a^3 + b^3 + ...)
//this results in smaller distances along the diagonal axes.
float cubeLength(const in vec2 v) {
	return pow(abs(v.x * v.x * v.x) + abs(v.y * v.y * v.y), 1.0 / 3.0);
}

float getDistortFactor(const in vec2 v) {
	return cubeLength(v) + SHADOW_DISTORT_FACTOR;
}

vec3 distort(const in vec3 v, const in float factor) {
	return vec3(v.xy / factor, v.z * 0.5);
}

vec3 distort(const in vec3 v) {
	return distort(v, getDistortFactor(v.xy));
}

#if defined RENDER_VERTEX && !defined RENDER_SHADOW
	void ApplyShadows(const in vec4 viewPos) {
		// #if defined RENDER_TERRAIN && defined SHADOW_EXCLUDE_FOLIAGE
		// 	//when SHADOW_EXCLUDE_FOLIAGE is enabled, act as if foliage is always facing towards the sun.
		// 	//in other words, don't darken the back side of it unless something else is casting a shadow on it.
		// 	if (mc_Entity.x >= 10000.0 && mc_Entity.x <= 10004.0) geoNoL = 1.0;
		// #endif

		if (geoNoL > 0.0) { //vertex is facing towards the sun
			vec4 playerPos = gbufferModelViewInverse * viewPos;

			shadowPos = (shadowProjection * (shadowModelView * playerPos)).xyz; //convert to shadow screen space

			#if SHADOW_TYPE == 2
				float distortFactor = getDistortFactor(shadowPos.xy);
				shadowPos = distort(shadowPos, distortFactor); //apply shadow distortion
				shadowPos.z -= SHADOW_DISTORTED_BIAS * SHADOW_BIAS_SCALE * (distortFactor * distortFactor) / abs(geoNoL); //apply shadow bias
			#elif SHADOW_TYPE == 1
				//shadowPos.z *= 0.5;
				float range = min(shadowDistance, far * SHADOW_CSM_FIT_FARSCALE);
				float shadowResScale = range / shadowMapSize;
				float bias = SHADOW_BASIC_BIAS * shadowResScale * SHADOW_BIAS_SCALE;
				shadowPos.z -= min(bias / abs(geoNoL), 0.1); //apply shadow bias
			#endif

			shadowPos = shadowPos * 0.5 + 0.5; //convert from -1 ~ +1 to 0 ~ 1
		}
		else { //vertex is facing away from the sun
			// mark that this vertex does not need to check the shadow map.
			shadowPos = vec3(0.0);
		}
	}
#endif

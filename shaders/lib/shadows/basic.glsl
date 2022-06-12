#ifdef RENDER_VERTEX
	#if SHADOW_TYPE == 2
		//euclidian distance is defined as sqrt(a^2 + b^2 + ...)
		//this length function instead does cbrt(a^3 + b^3 + ...)
		//this results in smaller distances along the diagonal axes.
		float cubeLength(vec2 v) {
			return pow(abs(v.x * v.x * v.x) + abs(v.y * v.y * v.y), 1.0 / 3.0);
		}

		float getDistortFactor(vec2 v) {
			return cubeLength(v) + SHADOW_DISTORT_FACTOR;
		}

		vec3 distort(vec3 v, float factor) {
			return vec3(v.xy / factor, v.z * 0.5);
		}

		vec3 distort(vec3 v) {
			return distort(v, getDistortFactor(v.xy));
		}
	#endif

	#ifndef RENDER_SHADOW
		void ApplyShadows(const in vec4 viewPos) {
			// #if defined RENDER_TERRAIN && defined SHADOW_EXCLUDE_FOLIAGE
			// 	//when SHADOW_EXCLUDE_FOLIAGE is enabled, act as if foliage is always facing towards the sun.
			// 	//in other words, don't darken the back side of it unless something else is casting a shadow on it.
			// 	if (mc_Entity.x >= 10000.0 && mc_Entity.x <= 10004.0) geoNoL = 1.0;
			// #endif

			if (geoNoL > 0.0) { //vertex is facing towards the sun
				vec4 playerPos = gbufferModelViewInverse * viewPos;

				#if RENDER_TEXTURED
					shadowPos = (shadowProjection * (shadowModelView * playerPos)).xyz; //convert to shadow screen space
				#else
					shadowPos = shadowProjection * (shadowModelView * playerPos); //convert to shadow screen space
				#endif

				#if SHADOW_TYPE == 2
					float distortFactor = getDistortFactor(shadowPos.xy);
					shadowPos.xyz = distort(shadowPos.xyz, distortFactor); //apply shadow distortion
					shadowPos.z -= SHADOW_DISTORTED_BIAS * SHADOW_BIAS_SCALE * (distortFactor * distortFactor) / abs(geoNoL); //apply shadow bias
				#elif SHADOW_TYPE == 1
					//shadowPos.z *= 0.5;
					float shadowResScale = range / shadowMapResolution;
					float range = min(shadowDistance, far * SHADOW_CSM_FIT_FARSCALE);
					float bias = SHADOW_BASIC_BIAS * shadowResScale * SHADOW_BIAS_SCALE;
					shadowPos.z -= min(bias / abs(geoNoL), 0.1); //apply shadow bias
				#endif

				shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5; //convert from -1 ~ +1 to 0 ~ 1
			}
			else { //vertex is facing away from the sun
				// mark that this vertex does not need to check the shadow map.
				#if RENDER_TEXTURED
					shadowPos = vec3(0.0);
				#else
					shadowPos = vec4(0.0);
				#endif
			}
		}
	#endif
#endif

#ifdef RENDER_FRAG
	#if SHADOW_COLORS == 1
		vec3 GetShadowColor() {
			//when colored shadows are enabled and there's nothing OPAQUE between us and the sun,
			//perform a 2nd check to see if there's anything translucent between us and the sun.
			if (texture2D(shadowtex0, shadowPos.xy).r >= shadowPos.z) return vec3(1.0);

			//surface has translucent object between it and the sun. modify its color.
			//if the block light is high, modify the color less.
			vec4 shadowLightColor = texture2D(shadowcolor0, shadowPos.xy);
			vec3 color = RGBToLinear(shadowLightColor.rgb);

			//make colors more intense when the shadow light color is more opaque.
			return mix(vec3(1.0), color, shadowLightColor.a);
		}
	#endif

	float SampleDepth(const in vec2 offset) {
		#if SHADOW_COLORS == 0
			//for normal shadows, only consider the closest thing to the sun,
			//regardless of whether or not it's opaque.
			#ifdef RENDER_TEXTURED
				return texture2D(shadowtex0, shadowPos.xy + offset).r;
			#else
				return texture2DProj(shadowtex0, vec4(shadowPos.xy + offset * shadowPos.w, shadowPos.z, shadowPos.w)).r;
			#endif
		#else
			//for invisible and colored shadows, first check the closest OPAQUE thing to the sun.
			#ifdef RENDER_TEXTURED
				return texture2D(shadowtex1, shadowPos.xy + offset).r;
			#else
				return texture2DProj(shadowtex1, vec4(shadowPos.xy + offset * shadowPos.w, shadowPos.z, shadowPos.w)).r;
			#endif
		#endif
	}

	#if SHADOW_FILTER != 0
		// PCF
		// float GetShadowing_PCF(int radius) {
		// 	float texDepth;
		// 	int sampleCount = 0;
		// 	float shadow = 0.0;
		// 	for (int y = -radius; y <= radius; y++) {
		// 		for (int x = -radius; x <= radius; x++) {
		// 			vec2 offset = vec2(x, y) * shadowPixelSize;

		// 			float texDepth = SampleDepth(offset);

		// 			//if (texDepth + EPSILON >= 1.0) continue;

		// 			//shadow += shadowPos.z > texDepth ? 1.0 : 0.0;
		// 			shadow += step(texDepth + EPSILON, shadowPos.z);
		// 			sampleCount++;
		// 		}
		// 	}

		// 	return sampleCount < 1 ? 0.0 : min(shadow / sampleCount, 1.0);
		// }

		#define POISSON_SAMPLES 36
		const vec2 poissonDisk[POISSON_SAMPLES] = vec2[](
			vec2(-1.666556, 3.323026),
			vec2( 0.2221941, 3.160916),
			vec2(-1.893797, 4.687831),
			vec2(-1.276664, 0.9222447),
			vec2(-3.629881, 3.348944),
			vec2(-2.712132, 1.906398),
			vec2(-2.671917, 0.2927003),
			vec2(-4.545432, 0.1704162),
			vec2(-4.042074, 1.560578),
			vec2(-0.4609011, -0.1767054),
			vec2(-0.3247355, 1.863549),
			vec2(-2.593971, -2.044478),
			vec2(-4.095399, -1.293885),
			vec2(-1.238809, -1.770761),
			vec2( 1.796596, 1.167886),
			vec2( 0.773102, -1.077155),
			vec2(-1.453834, -3.095817),
			vec2(-3.803265, -3.197731),
			vec2( 3.11283, -0.6977059),
			vec2( 3.845328, 1.689705),
			vec2( 2.372247, 2.7577),
			vec2( 0.1328599, -3.005355),
			vec2(-0.3344785, -5.29612),
			vec2(-0.06073825, 5.078752),
			vec2(-2.309451, -4.194909),
			vec2( 5.097953,  1.165748),
			vec2( 4.321077,  0.0005562016),
			vec2( 4.549654,  3.009906),
			vec2(-5.40501,  -0.9731998),
			vec2( 2.150302,  4.912695),
			vec2( 5.221128, -1.13326),
			vec2( 1.481966, -2.525289),
			vec2( 3.236365, -2.852343),
			vec2( 1.118359, -4.146132),
			vec2( 2.667908, -4.248179),
			vec2( 4.654964, -2.35809));

		float GetShadowing_PCF(float radius) {

			float texDepth;
			float shadow = 0.0;
			for (int i = 0; i < POISSON_SAMPLES; i++) {
				vec2 offset = (poissonDisk[i] / 6.0) * radius * shadowPixelSize;

				float texDepth = SampleDepth(offset);

				//if (texDepth + EPSILON >= 1.0) continue;

				//shadow += shadowPos.z > texDepth ? 1.0 : 0.0;
				shadow += step(texDepth + EPSILON, shadowPos.z);
			}

			return shadow / POISSON_SAMPLES;
		}
	#endif

	#if SHADOW_FILTER == 2
		// PCF + PCSS
		#define PCSS_NEAR 1.0
		#define SHADOW_BLOCKER_SAMPLES 16
		#define SHADOW_LIGHT_SIZE 0.0002

		float FindBlockerDistance(float searchWidth) {
			//float searchWidth = SearchWidth(uvLightSize, shadowPos.z);
			//float searchWidth = 6.0; //SHADOW_LIGHT_SIZE * (shadowPos.z - PCSS_NEAR) / shadowPos.z;
			float avgBlockerDistance = 0;
			int blockers = 0;

			for (int i = 0; i < SHADOW_BLOCKER_SAMPLES; i++) {
				float texDepth = SampleDepth(poissonDisk[i] * searchWidth);

				if (texDepth < shadowPos.z) { // - directionalLightShadowMapBias
					avgBlockerDistance += texDepth;
					blockers++;
				}
			}

			return blockers > 0 ? avgBlockerDistance / blockers : -1.0;
		}

		float GetShadowing() {
			// blocker search
			float blockerDistance = FindBlockerDistance(0.0004);
			if (blockerDistance < 0.0) return 1.0;

			//return 0.0;

			// penumbra estimation
			float penumbraWidth = (shadowPos.z - blockerDistance) / blockerDistance;

			//return clamp(1.0 - penumbraWidth, 0.0, 1.0);

			// percentage-close filtering
			float uvRadius = clamp(penumbraWidth * 200.0, 0.0, 32.0); // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;
			return 1.0 - GetShadowing_PCF(uvRadius);
		}
	#elif SHADOW_FILTER == 1
		// PCF
		float GetShadowing() {
			return 1.0 - GetShadowing_PCF(16.0);
		}
	#elif SHADOW_FILTER == 0
		// Unfiltered
		float GetShadowing() {
			float texDepth = SampleDepth(vec2(0.0));
			return step(shadowPos.z, texDepth);
		}
	#endif
#endif

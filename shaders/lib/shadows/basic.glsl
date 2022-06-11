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
			vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
			vec3 lightDir = normalize(shadowLightPosition);
			geoNoL = dot(lightDir, normal);

			#if defined RENDER_TERRAIN && defined SHADOW_EXCLUDE_FOLIAGE
				//when SHADOW_EXCLUDE_FOLIAGE is enabled, act as if foliage is always facing towards the sun.
				//in other words, don't darken the back side of it unless something else is casting a shadow on it.
				if (mc_Entity.x >= 10000.0 && mc_Entity.x <= 10004.0) geoNoL = 1.0;
			#endif

			if (geoNoL > 0.0) { //vertex is facing towards the sun
				vec4 playerPos = gbufferModelViewInverse * viewPos;

				shadowPos = (shadowProjection * (shadowModelView * playerPos)).xyz; //convert to shadow screen space

				#if SHADOW_TYPE == 2
					float distortFactor = getDistortFactor(shadowPos.xy);
					shadowPos.xyz = distort(shadowPos.xyz, distortFactor); //apply shadow distortion
					shadowPos.z -= SHADOW_BIAS * (distortFactor * distortFactor) / abs(geoNoL); //apply shadow bias
				#else
					//shadowPos.z *= 0.5;
					float shadowResScale = (1.0 / shadowMapResolution) * 0.05;
					float bias = far * shadowResScale * SHADOW_BIAS_SCALE;
					shadowPos.z -= min(bias / abs(geoNoL), 0.1); //apply shadow bias
				#endif

				shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5; //convert from -1 ~ +1 to 0 ~ 1
			}
			else { //vertex is facing away from the sun
				// mark that this vertex does not need to check the shadow map.
				shadowPos = vec3(0.0);
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

	#if SHADOW_FILTER == 2
		// PCF + PCSS
		float GetShadowing() {
			#if SHADOW_COLORS == 0
				//for normal shadows, only consider the closest thing to the sun,
				//regardless of whether or not it's opaque.
				float depth = texture2D(shadowtex0, shadowPos.xy).r;
			#else
				//for invisible and colored shadows, first check the closest OPAQUE thing to the sun.
				float depth = texture2D(shadowtex1, shadowPos.xy).r;
			#endif

			//return (depth < shadowPos.z) ? 0.0 : 1.0;
			return step(shadowPos.z, depth);
		}
	#elif SHADOW_FILTER == 1
		// PCF
		float GetShadowing() {
			const int radius = 2;
			float shadowPixelSize = (1.0 / shadowMapResolution);// * 0.5;

			float texDepth;
			int sampleCount = 0;
			float shadow = 0.0;
			for (int y = -radius; y <= radius; y++) {
				for (int x = -radius; x <= radius; x++) {
					vec2 texcoord = shadowPos.xy + vec2(x, y) * shadowPixelSize;

					#if SHADOW_COLORS == 0
						//for normal shadows, only consider the closest thing to the sun,
						//regardless of whether or not it's opaque.
						texDepth = texture2D(shadowtex0, texcoord).r;
					#else
						//for invisible and colored shadows, first check the closest OPAQUE thing to the sun.
						texDepth = texture2D(shadowtex1, texcoord).r;
					#endif

					//if (texDepth + EPSILON >= 1.0) continue;

					//shadow += shadowPos.z > texDepth ? 1.0 : 0.0;
					shadow += step(texDepth, shadowPos.z);
					sampleCount++;
				}
			}

			if (sampleCount < 1) return 1.0;
			return 1.0 - min(shadow / sampleCount, 1.0);
		}
	#elif SHADOW_FILTER == 0
		// Unfiltered
		float GetShadowing() {
			#if SHADOW_COLORS == 0
				//for normal shadows, only consider the closest thing to the sun,
				//regardless of whether or not it's opaque.
				float depth = texture2D(shadowtex0, shadowPos.xy).r;
			#else
				//for invisible and colored shadows, first check the closest OPAQUE thing to the sun.
				float depth = texture2D(shadowtex1, shadowPos.xy).r;
			#endif

			//return (depth < shadowPos.z) ? 0.0 : 1.0;
			return step(shadowPos.z, depth);
		}
	#endif
#endif

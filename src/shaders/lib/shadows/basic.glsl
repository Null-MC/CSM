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
					shadowPos.z -= SHADOW_BIAS / abs(geoNoL); //apply shadow bias
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
	float GetShadowing(out vec3 color) {
		// if (shadowPos.x < 0.0 || shadowPos.x > 1.0
		//  || shadowPos.y < 0.0 || shadowPos.y > 1.0) {
		// 	lm.y = mix(31.0 / 32.0 * SHADOW_BRIGHTNESS, 31.0 / 32.0, sqrt(geoNoL));
		// }

		//surface is facing towards shadowLightPosition
		#if SHADOW_COLORS == 0
			//for normal shadows, only consider the closest thing to the sun,
			//regardless of whether or not it's opaque.
			float depth = texture2D(shadowtex0, shadowPos.xy).r;
		#else
			//for invisible and colored shadows, first check the closest OPAQUE thing to the sun.
			float depth = texture2D(shadowtex1, shadowPos.xy).r;
		#endif

		if (depth < shadowPos.z) {
			color = vec3(1.0);
			return 0.0;
		}
		
		color = vec3(1.0);
		#if SHADOW_COLORS == 1
			//when colored shadows are enabled and there's nothing OPAQUE between us and the sun,
			//perform a 2nd check to see if there's anything translucent between us and the sun.
			if (texture2D(shadowtex0, shadowPos.xy).r < shadowPos.z) {
				//surface has translucent object between it and the sun. modify its color.
				//if the block light is high, modify the color less.
				vec4 shadowLightColor = texture2D(shadowcolor0, shadowPos.xy);
				color = RGBToLinear(shadowLightColor.rgb);

				//make colors more intense when the shadow light color is more opaque.
				color = mix(vec3(1.0), color, shadowLightColor.a);
			}
		#endif

		return 1.0;
	}
#endif

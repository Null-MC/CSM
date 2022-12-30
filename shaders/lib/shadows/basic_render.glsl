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
		return texture2D(shadowtex0, shadowPos.xy + offset).r;
	#else
		//for invisible and colored shadows, first check the closest OPAQUE thing to the sun.
		return texture2D(shadowtex1, shadowPos.xy + offset).r;
	#endif
}

#ifdef SHADOW_ENABLE_HWCOMP
    // returns: [0] when depth occluded, [1] otherwise
    float CompareDepth(const in vec2 offset) {
        return shadow2D(shadow, shadowPos.xyz + vec3(offset, 0.0)).r;
    }

    #if SHADOW_FILTER != 0
        // PCF
        float GetShadowing_PCF(const in vec2 pixelRadius, const in int sampleCount) {
            float shadow = 0.0;
            for (int i = 0; i < sampleCount; i++) {
                vec2 pixelOffset = (hash23(vec3(gl_FragCoord.xy, i))*2.0 - 1.0) * pixelRadius;
                shadow += 1.0 - CompareDepth(pixelOffset);
            }

            return shadow / sampleCount;
        }
    #endif
#else
    #if SHADOW_FILTER != 0
        // PCF
        float GetShadowing_PCF(const in vec2 pixelRadius, const in int sampleCount) {
            float texDepth;
            float shadow = 0.0;
            for (int i = 0; i < sampleCount; i++) {
                vec2 pixelOffset = (hash23(vec3(gl_FragCoord.xy, i))*2.0 - 1.0) * pixelRadius;
                float texDepth = SampleDepth(pixelOffset);
                shadow += step(texDepth + EPSILON, shadowPos.z);
            }

            //if (sampleCount <= 1) return shadow;
            return shadow / sampleCount;

            // #if SHADOW_FILTER == 1
            //     float f = 1.0 - max(geoNoL, 0.0);
            //     f = clamp(shadow / sampleCount - 0.7*f, 0.0, 1.0) * (1.0 + (1.0/0.3) * f);
            //     return clamp(f, 0.0, 1.0);
            // #else
            //     return expStep(shadow / sampleCount);
            // #endif
        }
    #endif
#endif

#if SHADOW_FILTER != 0
    vec2 GetShadowPixelRadius(const in float blockRadius) {
        vec2 shadowProjectionSize = 2.0 / vec2(shadowProjection[0].x, shadowProjection[1].y);

        #if SHADOW_TYPE == 2
            float distortFactor = getDistortFactor(shadowPos.xy * 2.0 - 1.0);
            float maxRes = shadowMapSize / SHADOW_DISTORT_FACTOR;
            //float maxResPixel = 1.0 / maxRes;

            vec2 pixelPerBlockScale = maxRes / shadowProjectionSize;
            return blockRadius * pixelPerBlockScale * shadowPixelSize * (1.0 - distortFactor);
        #else
            vec2 pixelPerBlockScale = shadowMapSize / shadowProjectionSize;
            return blockRadius * pixelPerBlockScale * shadowPixelSize;
        #endif
    }
#endif

#if SHADOW_FILTER == 2
	// PCF + PCSS
	//#define PCSS_NEAR 1.0
	#define SHADOW_BLOCKER_SAMPLES 12
	//#define SHADOW_LIGHT_SIZE 0.0002

	float FindBlockerDistance(const in vec2 pixelRadius, const in int sampleCount) {
		//float radius = SearchWidth(uvLightSize, shadowPos.z);
		//float radius = 6.0; //SHADOW_LIGHT_SIZE * (shadowPos.z - PCSS_NEAR) / shadowPos.z;
		float avgBlockerDistance = 0;
		int blockers = 0;

		for (int i = 0; i < sampleCount; i++) {
			vec2 offset = (hash23(vec3(gl_FragCoord.xy, i))*2.0 - 1.0) * pixelRadius;
			float texDepth = SampleDepth(offset);

			if (texDepth < shadowPos.z) { // - directionalLightShadowMapBias
				avgBlockerDistance += texDepth;
				blockers++;
			}
		}

		return blockers > 0 ? avgBlockerDistance / blockers : -1.0;
	}

	float GetShadowing() {
		vec2 pixelRadius = GetShadowPixelRadius(SHADOW_PCF_SIZE);

		// blocker search
		int blockerSampleCount = SHADOW_BLOCKER_SAMPLES;
		if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) blockerSampleCount = 1;
		float blockerDistance = FindBlockerDistance(pixelRadius, blockerSampleCount);
		if (blockerDistance < 0.0) return 1.0;

		// penumbra estimation
		float penumbraWidth = (shadowPos.z - blockerDistance) / blockerDistance;

		// percentage-close filtering
		pixelRadius *= min(penumbraWidth * 40.0, 1.0); // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;

		int pcfSampleCount = SHADOW_PCF_SAMPLES;
		if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) pcfSampleCount = 1;
		return 1.0 - GetShadowing_PCF(pixelRadius, pcfSampleCount);
	}
#elif SHADOW_FILTER == 1
	// PCF
	float GetShadowing() {
		vec2 pixelRadius = GetShadowPixelRadius(SHADOW_PCF_SIZE);

		int sampleCount = SHADOW_PCF_SAMPLES;
		if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;
		return 1.0 - GetShadowing_PCF(pixelRadius, sampleCount);
	}
#elif SHADOW_FILTER == 0
	// Unfiltered
	float GetShadowing() {
		float texDepth = SampleDepth(vec2(0.0));
		return step(shadowPos.z, texDepth);
	}
#endif
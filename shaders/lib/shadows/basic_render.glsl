// #if SHADOW_COLORS == 1
//  vec3 GetShadowColor(const in vec3 shadowPos) {
//      //when colored shadows are enabled and there's nothing OPAQUE between us and the sun,
//      //perform a 2nd check to see if there's anything translucent between us and the sun.
//      if (texture(shadowtex0, shadowPos.xy).r >= shadowPos.z) return vec3(1.0);

//      //surface has translucent object between it and the sun. modify its color.
//      //if the block light is high, modify the color less.
//      vec4 shadowLightColor = texture(shadowcolor0, shadowPos.xy);
//      vec3 color = RGBToLinear(shadowLightColor.rgb);

//      //make colors more intense when the shadow light color is more opaque.
//      return mix(vec3(1.0), color, shadowLightColor.a);
//  }
// #endif

float GetShadowBias(const in float geoNoL) {
    return 0.000004;
}

float SampleDepth(const in vec2 shadowPos, const in vec2 offset) {
    #if SHADOW_COLORS == 0
        //for normal shadows, only consider the closest thing to the sun,
        //regardless of whether or not it's opaque.
        return texture(shadowtex0, shadowPos + offset).r;
    #else
        //for invisible and colored shadows, first check the closest OPAQUE thing to the sun.
        return texture(shadowtex1, shadowPos + offset).r;
    #endif
}

// returns: [0] when depth occluded, [1] otherwise
float CompareDepth(const in vec3 shadowPos, const in vec2 offset, const in float bias) {
    #ifdef SHADOW_ENABLE_HWCOMP
        #ifdef IS_IRIS
            return texture(shadowtex0HW, shadowPos + vec3(offset, -bias)).r;
        #else
            return texture(shadow, shadowPos + vec3(offset, -bias)).r;
        #endif
    #else
        #if SHADOW_COLORS == SHADOW_COLOR_IGNORED
            float texDepth = texture(shadowtex1, shadowPos.xy + offset).r;
        #else
            float texDepth = texture(shadowtex0, shadowPos.xy + offset).r;
        #endif

        return step(shadowPos.z - bias, texDepth);
    #endif
}


#if SHADOW_FILTER != 0
    // PCF
    #if SHADOW_COLORS == SHADOW_COLOR_ENABLED
        vec3 GetShadowing_PCF(const in vec3 shadowPos, const in vec2 pixelRadius, const in int sampleCount) {
            float bias = GetShadowBias(geoNoL);
            vec3 shadowColor = vec3(0.0);
            
            for (int i = 0; i < sampleCount; i++) {
                vec3 noisePos = vec3(gl_FragCoord.xy, i);
                vec2 pixelOffset = (hash23(noisePos)*2.0 - 1.0) * pixelRadius;
                vec4 sampleColor = vec4(1.0);

                float depthOpaque = textureLod(shadowtex1, shadowPos.xy + pixelOffset, 0).r;

                if (shadowPos.z - bias > depthOpaque) sampleColor.rgb = vec3(0.0);
                else {
                    float depthTrans = textureLod(shadowtex0, shadowPos.xy + pixelOffset, 0).r;
                    if (shadowPos.z - bias < depthTrans) sampleColor.rgb = vec3(1.0);
                    else {
                        sampleColor = textureLod(shadowcolor0, shadowPos.xy + pixelOffset, 0);
                        sampleColor.rgb = RGBToLinear(sampleColor.rgb);
                        
                        sampleColor.rgb = mix(sampleColor.rgb, vec3(0.0), pow2(sampleColor.a));
                    }
                }

                shadowColor += sampleColor.rgb;
            }

            return shadowColor / sampleCount;
        }
    #else
        float GetShadowing_PCF(const in vec3 shadowPos, const in vec2 pixelRadius, const in int sampleCount) {
            float bias = GetShadowBias(geoNoL);

            float shadow = 0.0;
            for (int i = 0; i < sampleCount; i++) {
                vec3 noisePos = vec3(gl_FragCoord.xy, i);
                vec2 pixelOffset = (hash23(noisePos)*2.0 - 1.0) * pixelRadius;
                shadow += 1.0 - CompareDepth(shadowPos, pixelOffset, bias);
            }

            return shadow / sampleCount;
        }
    #endif

    vec2 GetShadowPixelRadius(const in float blockRadius) {
        vec2 shadowProjectionSize = 2.0 / vec2(shadowProjection[0].x, shadowProjection[1].y);

        #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
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
    float FindBlockerDistance(const in vec3 shadowPos, const in vec2 pixelRadius, const in int sampleCount) {
        //float radius = SearchWidth(uvLightSize, shadowPos.z);
        //float radius = 6.0; //SHADOW_LIGHT_SIZE * (shadowPos.z - PCSS_NEAR) / shadowPos.z;
        float avgBlockerDistance = 0;
        int blockers = 0;

        for (int i = 0; i < sampleCount; i++) {
            vec2 offset = (hash23(vec3(gl_FragCoord.xy, i))*2.0 - 1.0) * pixelRadius;

            #if SHADOW_COLORS == SHADOW_COLOR_IGNORED
                float texDepth = texture(shadowtex1, shadowPos.xy + offset).r;
            #else
                float texDepth = texture(shadowtex0, shadowPos.xy + offset).r;
            #endif

            if (texDepth < shadowPos.z) { // - directionalLightShadowMapBias
                avgBlockerDistance += texDepth;
                blockers++;
            }
        }

        return blockers > 0 ? avgBlockerDistance / blockers : 0.0;
    }

    #if SHADOW_COLORS == SHADOW_COLOR_ENABLED
        vec3 GetShadowColor(const in vec3 shadowPos) {
            vec2 pixelRadius = GetShadowPixelRadius(SHADOW_PCF_SIZE);

            // blocker search
            int blockerSampleCount = SHADOW_PCSS_SAMPLES;
            if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) blockerSampleCount = 1;
            float blockerDistance = FindBlockerDistance(shadowPos, pixelRadius, blockerSampleCount);

            if (blockerDistance <= 0.0) {
                float bias = GetShadowBias(geoNoL);

                //float depthOpaque = textureLod(shadowtex1, shadowPos.xy, 0).r;
                //if (shadowPos.z - bias > depthOpaque) return vec3(0.0);

                float depthTrans = textureLod(shadowtex0, shadowPos.xy, 0).r;
                if (shadowPos.z - bias < depthTrans) return vec3(1.0);

                vec4 shadowColor = textureLod(shadowcolor0, shadowPos.xy, 0);
                shadowColor.rgb = RGBToLinear(shadowColor.rgb);

                shadowColor.rgb = mix(shadowColor.rgb, vec3(0.0), pow2(shadowColor.a));
                
                return shadowColor.rgb;
            }

            // penumbra estimation
            float penumbraWidth = (shadowPos.z - blockerDistance) / blockerDistance;

            // percentage-close filtering
            pixelRadius *= min(penumbraWidth * 20.0, 1.0); // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;

            int pcfSampleCount = SHADOW_PCF_SAMPLES;
            if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) pcfSampleCount = 1;
            return GetShadowing_PCF(shadowPos, pixelRadius, pcfSampleCount);
        }
    #else
        float GetShadowFactor(const in vec3 shadowPos) {
            vec2 pixelRadius = GetShadowPixelRadius(SHADOW_PCF_SIZE);

            // blocker search
            int blockerSampleCount = SHADOW_PCSS_SAMPLES;
            if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) blockerSampleCount = 1;
            float blockerDistance = FindBlockerDistance(shadowPos, pixelRadius, blockerSampleCount);
            if (blockerDistance <= 0.0) return 1.0;

            // penumbra estimation
            float penumbraWidth = (shadowPos.z - blockerDistance) / blockerDistance;

            // percentage-close filtering
            pixelRadius *= min(penumbraWidth * 20.0, 1.0); // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;

            int pcfSampleCount = SHADOW_PCF_SAMPLES;
            if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) pcfSampleCount = 1;
            return 1.0 - GetShadowing_PCF(shadowPos, pixelRadius, pcfSampleCount);
        }
    #endif
#elif SHADOW_FILTER == 1
    // PCF
    #if SHADOW_COLORS == SHADOW_COLOR_ENABLED
        vec3 GetShadowColor(const in vec3 shadowPos) {
            vec2 pixelRadius = GetShadowPixelRadius(SHADOW_PCF_SIZE);

            int sampleCount = SHADOW_PCF_SAMPLES;
            if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;
            return GetShadowing_PCF(shadowPos, pixelRadius, sampleCount);
        }
    #else
        float GetShadowFactor(const in vec3 shadowPos) {
            vec2 pixelRadius = GetShadowPixelRadius(SHADOW_PCF_SIZE);

            int sampleCount = SHADOW_PCF_SAMPLES;
            if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;
            return 1.0 - GetShadowing_PCF(shadowPos, pixelRadius, sampleCount);
        }
    #endif
#elif SHADOW_FILTER == 0
    // Unfiltered
    #if SHADOW_COLORS == SHADOW_COLOR_ENABLED
        vec3 GetShadowColor(const in vec3 shadowPos) {
            float bias = GetShadowBias(geoNoL);

            float depthOpaque = texture(shadowtex1, shadowPos.xy).r;
            if (shadowPos.z - bias > depthOpaque) return vec3(0.0);

            float depthTrans = texture(shadowtex0, shadowPos.xy).r;
            if (shadowPos.z - bias < depthTrans) return vec3(1.0);

            vec4 shadowColor = texture(shadowcolor0, shadowPos.xy);
            shadowColor.rgb = RGBToLinear(shadowColor.rgb);

            shadowColor.rgb = mix(shadowColor.rgb, vec3(0.0), pow2(shadowColor.a));
            
            return shadowColor.rgb;
        }
    #else
        float GetShadowFactor(const in vec3 shadowPos) {
            float bias = GetShadowBias(geoNoL);
            return CompareDepth(shadowPos, vec2(0.0), bias);
        }
    #endif
#endif

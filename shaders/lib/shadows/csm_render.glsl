#define PCF_MAX_RADIUS 0.16

const float cascadeTexSize = shadowMapSize * 0.5;
const float tile_dist_bias_factor = 0.012288;
const int pcf_sizes[4] = int[](4, 3, 2, 1);
const int pcf_max = 4;


float GetShadowBias(const in int tile, const in float geoNoL) {
    return 0.000004;

    // float blocksPerPixelScale = max(shadowProjectionSize[tile].x, shadowProjectionSize[tile].y) / cascadeTexSize;

    // float zRangeBias = 0.0000001;
    // float xySizeBias = blocksPerPixelScale * tile_dist_bias_factor;
    // return mix(xySizeBias, zRangeBias, geoNoL) * SHADOW_BIAS_SCALE;
}

float SampleDepth(const in vec2 shadowPos, const in vec2 offset) {
    #if SHADOW_COLORS == 0
        return textureLod(shadowtex0, shadowPos + offset, 0).r;
    #else
        return textureLod(shadowtex1, shadowPos + offset, 0).r;
    #endif
}

vec2 GetPixelRadius(const in float blockRadius, const in int tile) {
    return blockRadius * (cascadeTexSize / shadowProjectionSize[tile]) * shadowPixelSize;
}

bool IsSampleWithinCascade(const in vec2 shadowPos, const in int cascade, const in float blockRadius) {
    vec2 padding = blockRadius / shadowProjectionSize[cascade];

    #ifdef IRIS_FEATURE_SSBO
        vec2 clipMin = shadowProjectionPos[cascade] + padding;
        vec2 clipMax = shadowProjectionPos[cascade] + 0.5 - padding;
    #else
        vec2 shadowTilePos = GetShadowTilePos(cascade);
        vec2 clipMin = shadowTilePos + padding;
        vec2 clipMax = shadowTilePos + 0.5 - padding;
    #endif

    //return clamp(shadowPos, clipMin, clipMax) == shadowPos;
    return all(greaterThan(shadowPos, clipMin)) && all(lessThan(shadowPos, clipMax));
}

int GetShadowCascade(const in vec3 shadowPos[4], const in float blockRadius) {
    //return 0;

    if (IsSampleWithinCascade(shadowPos[0].xy, 0, blockRadius)) return 0;
    if (IsSampleWithinCascade(shadowPos[1].xy, 1, blockRadius)) return 1;
    if (IsSampleWithinCascade(shadowPos[2].xy, 2, blockRadius)) return 2;
    if (IsSampleWithinCascade(shadowPos[3].xy, 3, blockRadius)) return 3;
    return -1;

    // if (!IsSampleWithinCascade(shadowPos[3].xy, 3, blockRadius)) return -1;
    // else if (!IsSampleWithinCascade(shadowPos[2].xy, 2, blockRadius)) return 3;
    // else if (!IsSampleWithinCascade(shadowPos[1].xy, 1, blockRadius)) return 2;
    // else if (!IsSampleWithinCascade(shadowPos[0].xy, 0, blockRadius)) return 1;
    // else return 0;
}

// returns: [0] when depth occluded, [1] otherwise
float CompareDepth(const in vec3 shadowPos, const in vec2 offset, const in float bias) {
    #ifdef SHADOW_ENABLE_HWCOMP
        #ifdef IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
            return texture(shadowtex0HW, shadowPos + vec3(offset, -bias)).r;
        #else
            return texture(shadow, shadowPos + vec3(offset, -bias)).r;
        #endif
    #else
        float texDepth = SampleDepth(shadowPos.xy, offset);
        return step(shadowPos.z, texDepth + bias);
    #endif
}

#if SHADOW_FILTER != 0
    #if SHADOW_COLORS == SHADOW_COLOR_ENABLED
        vec3 GetShadowing_PCF(const in vec3 shadowPos, const in vec2 pixelRadius, const in int sampleCount, const in int tile) {
            float bias = GetShadowBias(tile, geoNoL);

            float startAngle = hash12(gl_FragCoord.xy) * (2.0 * PI);
            vec2 rotation = vec2(cos(startAngle), sin(startAngle));

            float angleDiff = PI * -2.0 / sampleCount;
            vec2 angleStep = vec2(cos(angleDiff), sin(angleDiff));
            mat2 rotationStep = mat2(angleStep, -angleStep.y, angleStep.x);

            vec3 shadowColor = vec3(0.0);
            for (int i = 0; i < sampleCount; i++) {
                rotation *= rotationStep;
                float noiseDist = hash13(vec3(gl_FragCoord.xy, i));
                vec2 pixelOffset = rotation * noiseDist * pixelRadius;
                float depthOpaque = textureLod(shadowtex1, shadowPos.xy + pixelOffset, 0).r;

                vec4 sampleColor = vec4(1.0);
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
        float GetShadowing_PCF(const in vec3 shadowPos, const in vec2 pixelRadius, const in int sampleCount, const in int tile) {
            float bias = GetShadowBias(tile, geoNoL);

            float startAngle = hash12(gl_FragCoord.xy) * (2.0 * PI);
            vec2 rotation = vec2(cos(startAngle), sin(startAngle));

            float angleDiff = PI * -2.0 / sampleCount;
            vec2 angleStep = vec2(cos(angleDiff), sin(angleDiff));
            mat2 rotationStep = mat2(angleStep, -angleStep.y, angleStep.x);

            float shadow = 0.0;
            for (int i = 0; i < sampleCount; i++) {
                rotation *= rotationStep;
                float noiseDist = hash13(vec3(gl_FragCoord.xy, i));
                vec2 pixelOffset = rotation * noiseDist * pixelRadius;
                
                shadow += 1.0 - CompareDepth(shadowPos, pixelOffset, bias);
            }

            return shadow / sampleCount;
        }
    #endif
#endif

#if SHADOW_FILTER == 2
    // PCF + PCSS
    float FindBlockerDistance(const in vec3 shadowPos, const in vec2 pixelRadius, const in int sampleCount) {
        float startAngle = hash12(gl_FragCoord.xy) * (2.0 * PI);
        vec2 rotation = vec2(cos(startAngle), sin(startAngle));

        float angleDiff = PI * -2.0 / sampleCount;
        vec2 angleStep = vec2(cos(angleDiff), sin(angleDiff));
        mat2 rotationStep = mat2(angleStep, -angleStep.y, angleStep.x);

        int blockers = 0;
        float avgBlockerDistance = 0;
        for (int i = 0; i < sampleCount; i++) {
            rotation *= rotationStep;
            float noiseDist = hash13(vec3(gl_FragCoord.xy, i + 100.0));
            vec2 pixelOffset = rotation * noiseDist * pixelRadius;

            #if SHADOW_COLORS == SHADOW_COLOR_IGNORED
                float texDepth = texture(shadowtex1, shadowPos.xy + pixelOffset).r;
            #else
                float texDepth = texture(shadowtex0, shadowPos.xy + pixelOffset).r;
            #endif

            if (texDepth < shadowPos.z) { // - directionalLightShadowMapBias
                avgBlockerDistance += texDepth;
                blockers++;
            }
        }

        //if (blockers == sampleCount) return 1.0;
        return blockers > 0 ? avgBlockerDistance / blockers : 0.0;
    }

    #if SHADOW_COLORS == SHADOW_COLOR_ENABLED
        vec3 GetShadowColor(const in vec3 shadowPos, const in int tile) {
            vec2 pixelRadius = GetPixelRadius(ShadowPCFSize, tile);

            // blocker search
            int blockerSampleCount = SHADOW_PCSS_SAMPLES;
            if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) blockerSampleCount = 1;
            float blockerDistance = FindBlockerDistance(shadowPos, pixelRadius, blockerSampleCount);

            if (blockerDistance <= 0.0) {
                float bias = GetShadowBias(tile, geoNoL);

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
            return GetShadowing_PCF(shadowPos, pixelRadius, pcfSampleCount, tile);
        }
    #else
        float GetShadowFactor(const in vec3 shadowPos, const in int tile) {
            vec2 pixelRadius = GetPixelRadius(ShadowPCFSize, tile);

            // blocker search
            int blockerSampleCount = SHADOW_PCSS_SAMPLES;
            //if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) blockerSampleCount = 1;
            float blockerDistance = FindBlockerDistance(shadowPos, pixelRadius, blockerSampleCount);
            if (blockerDistance <= 0.0) return 1.0;

            // penumbra estimation
            float penumbraWidth = (shadowPos.z - blockerDistance) / blockerDistance;

            // percentage-close filtering
            pixelRadius *= min(penumbraWidth * SHADOW_PENUMBRA_SCALE, 1.0); // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;

            int pcfSampleCount = SHADOW_PCF_SAMPLES;
            //if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) pcfSampleCount = 1;
            return 1.0 - GetShadowing_PCF(shadowPos, pixelRadius, pcfSampleCount, tile);
        }
    #endif
#elif SHADOW_FILTER == 1
    // PCF
    #if SHADOW_COLORS == SHADOW_COLOR_ENABLED
        vec3 GetShadowColor(const in vec3 shadowPos, const in int tile) {
            vec2 pixelRadius = GetPixelRadius(ShadowPCFSize, tile);
            
            int sampleCount = SHADOW_PCF_SAMPLES;
            //if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;
            return GetShadowing_PCF(shadowPos, pixelRadius, sampleCount, tile);
        }
    #else
        float GetShadowFactor(const in vec3 shadowPos, const in int tile) {
            vec2 pixelRadius = GetPixelRadius(ShadowPCFSize, tile);

            int sampleCount = SHADOW_PCF_SAMPLES;
            //if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;
            return 1.0 - GetShadowing_PCF(shadowPos, pixelRadius, sampleCount, tile);
        }
    #endif
#elif SHADOW_FILTER == 0
    // Unfiltered
    #if SHADOW_COLORS == SHADOW_COLOR_ENABLED
        vec3 GetShadowColor(const in vec3 shadowPos, const in int tile) {
            float bias = GetShadowBias(tile, geoNoL);

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
        float GetShadowFactor(const in vec3 shadowPos, const in int tile) {
            float bias = GetShadowBias(tile, geoNoL);
            return CompareDepth(shadowPos, vec2(0.0), bias);
        }
    #endif
#endif

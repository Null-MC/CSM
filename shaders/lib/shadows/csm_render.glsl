//#extension GL_ARB_texture_gather : enable

#define PCF_MAX_RADIUS 0.16

const float tile_dist_bias_factor = 0.012288;
const int pcf_sizes[4] = int[](4, 3, 2, 1);
const int pcf_max = 4;


float GetShadowBias(const in int tile, const in float geoNoL) {
    float cascadeTexSize = shadowMapSize * 0.5;
    float blocksPerPixelScale = max(shadowProjectionSize[tile].x, shadowProjectionSize[tile].y) / cascadeTexSize;

    float zRangeBias = 0.0000001;
    float xySizeBias = blocksPerPixelScale * tile_dist_bias_factor;
    return mix(xySizeBias, zRangeBias, geoNoL) * SHADOW_BIAS_SCALE;
}

float SampleDepth(const in vec2 offset, const in int tile) {
    #ifdef IS_OPTIFINE
        #if SHADOW_COLORS == 0
            return texture2D(shadowtex0, shadowPos[tile].xy + offset).r;
        #else
            return texture2D(shadowtex1, shadowPos[tile].xy + offset).r;
        #endif
    #else
        return texture2D(shadowtex0, shadowPos[tile].xy + offset).r;
    #endif
}

vec2 GetPixelRadius(const in vec2 blockRadius) {
    float texSize = shadowMapSize * 0.5;
    return blockRadius * (texSize / shadowProjectionSize[shadowTile]) * shadowPixelSize;
}

int GetShadowCascade(const in float blockRadius) {
    for (int i = 0; i < 4; i++) {
        vec2 padding = vec2(0.0);//blockRadius / shadowProjectionSize[tile];

        // Ignore if outside tile bounds
        vec2 shadowTilePos = GetShadowTilePos(i);
        vec2 clipMin = shadowTilePos + padding;
        vec2 clipMax = shadowTilePos + 0.5 - padding;

        if (clamp(shadowPos[i].xy, clipMin, clipMax) == shadowPos[i].xy) return i;
    }

    return -1;
}

#ifdef SHADOW_ENABLE_HWCOMP
    // returns: [0] when depth occluded, [1] otherwise
    float CompareDepth(const in vec2 offset, const in float bias, const in int tile) {
        #ifdef IS_OPTIFINE
            return shadow2D(shadow, shadowPos[tile].xyz + vec3(offset, -bias)).r;
        #else
            return shadow2D(shadowtex0HW, shadowPos[tile].xyz + vec3(offset, -bias)).r;
        #endif
    }
#endif

#if SHADOW_FILTER != 0
    float GetShadowing_PCF(const in float blockRadius, const in int sampleCount, const in int tile) {
        float cascadeTexSize = shadowMapSize * 0.5;
        vec2 pixelPerBlockScale = (cascadeTexSize / shadowProjectionSize[tile]) * shadowPixelSize;

        float bias = GetShadowBias(tile, geoNoL);

        float shadow = 0.0;
        for (int i = 0; i < sampleCount; i++) {
            vec2 blockOffset = (hash23(vec3(gl_FragCoord.xy, i))*2.0 - 1.0) * blockRadius;
            vec2 pixelOffset = blockOffset * pixelPerBlockScale;

            #ifdef SHADOW_ENABLE_HWCOMP
                shadow += 1.0 - CompareDepth(pixelOffset, bias, tile);
            #else
                float texDepth = SampleDepth(pixelOffset, tile);
                shadow += step(texDepth + bias, shadowPos[tile].z);
            #endif
        }

        return shadow / sampleCount;
        //return smoothstep(0.0, 1.0, shadow / sampleCount);
    }
#endif

#if SHADOW_COLORS == 1
    vec3 GetShadowColor() {
        int tile = GetShadowCascade(SHADOW_PCF_SIZE);
        if (tile < 0) return vec3(1.0);

        //when colored shadows are enabled and there's nothing OPAQUE between us and the sun,
        //perform a 2nd check to see if there's anything translucent between us and the sun.
        float depth = texture2D(shadowtex0, shadowPos[tile].xy).r;

        if (depth + EPSILON >= 1.0 || depth >= shadowPos[tile].z) return vec3(1.0);

        //surface has translucent object between it and the sun. modify its color.
        //if the block light is high, modify the color less.
        vec4 shadowLightColor = texture2D(shadowcolor0, shadowPos[tile].xy);
        vec3 color = RGBToLinear(shadowLightColor.rgb);

        //make colors more intense when the shadow light color is more opaque.
        return mix(vec3(1.0), color, shadowLightColor.a);
    }
#endif

#if SHADOW_FILTER == 2
    // PCF + PCSS
    #define SHADOW_BLOCKER_SAMPLES 12

    float FindBlockerDistance(const in float blockRadius, const in int sampleCount, const in int tile) {
        float cascadeTexSize = shadowMapSize * 0.5;
        vec2 pixelPerBlockScale = (cascadeTexSize / shadowProjectionSize[tile]) * shadowPixelSize;
        
        // NOTE: This optimization doesn't really help here rn since the search radius is fixed
        //if (blockRadius <= shadowPixelSize) sampleCount = 1;

        //float blockRadius = SearchWidth(uvLightSize, shadowPos.z);
        //float blockRadius = 6.0; //SHADOW_LIGHT_SIZE * (shadowPos.z - PCSS_NEAR) / shadowPos.z;
        float avgBlockerDistance = 0;
        int blockers = 0;

        for (int i = 0; i < sampleCount; i++) {
            vec2 blockOffset = (hash23(vec3(gl_FragCoord.xy, i))*2.0 - 1.0) * blockRadius;
            vec2 pixelOffset = blockOffset * pixelPerBlockScale;

            float texDepth = SampleDepth(pixelOffset, tile);

            if (texDepth < shadowPos[tile].z) { // - directionalLightShadowMapBias
                avgBlockerDistance += texDepth;
                blockers++;
            }
        }

        if (blockers == sampleCount) return 1.0;
        return blockers > 0 ? avgBlockerDistance / blockers : 0.0;
    }

    float GetShadowing() {
        int tile = GetShadowCascade(SHADOW_PCF_SIZE);
        if (tile < 0) return 1.0; // TODO: or 0?

        // blocker search
        int blockerSampleCount = SHADOW_BLOCKER_SAMPLES;
        float blockerDistance = FindBlockerDistance(SHADOW_PCF_SIZE, blockerSampleCount, tile);
        if (blockerDistance <= 0.0) return 1.0;
        if (blockerDistance >= 1.0) return 0.0;

        // penumbra estimation
        float penumbraWidth = (shadowPos[shadowTile].z - blockerDistance) / blockerDistance;

        // percentage-close filtering
        float blockRadius = saturate(penumbraWidth * 30.0) * SHADOW_PCF_SIZE; // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;

        int pcfSampleCount = SHADOW_PCF_SAMPLES;
        vec2 pixelRadius = GetPixelRadius(vec2(blockRadius));
        if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) pcfSampleCount = 1;

        return 1.0 - GetShadowing_PCF(blockRadius, pcfSampleCount, tile);
    }
#elif SHADOW_FILTER == 1
    // PCF
    float GetShadowing() {
        int tile = GetShadowCascade(SHADOW_PCF_SIZE);
        if (tile < 0) return 1.0; // TODO: or 0?

        int sampleCount = SHADOW_PCF_SAMPLES;
        vec2 pixelRadius = GetPixelRadius(vec2(SHADOW_PCF_SIZE));
        if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

        return 1.0 - max(GetShadowing_PCF(SHADOW_PCF_SIZE, sampleCount, tile) - 0.5*min(1.0 - geoNoL, 1.0), 0.0);
    }
#elif SHADOW_FILTER == 0
    // Unfiltered
    float GetShadowing() {
        int tile = GetShadowCascade(SHADOW_PCF_SIZE);
        if (tile < 0) return 1.0; // TODO: or 0?

        float bias = GetShadowBias(tile, geoNoL);

        #ifdef SHADOW_ENABLE_HWCOMP
            return CompareDepth(vec2(0.0), bias, tile);
        #else
            float texDepth = SampleDepth(vec2(0.0), tile);
            return step(shadowPos[tile].z, texDepth + bias);
        #endif
    }
#endif

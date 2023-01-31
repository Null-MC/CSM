#ifdef RENDER_VERTEX
    void BasicVertex() {
        vec4 pos = gl_Vertex;

        #if defined RENDER_TERRAIN && defined ENABLE_WAVING
            if (mc_Entity.x >= 10001.0 && mc_Entity.x <= 10004.0)
                pos.xyz += GetWavingOffset();
        #endif

        vec4 viewPos = gl_ModelViewMatrix * pos;

        vPos = viewPos.xyz;

        vNormal = normalize(gl_NormalMatrix * gl_Normal);

        #ifdef WORLD_SKY_ENABLED
            vec3 lightDir = normalize(shadowLightPosition);
            geoNoL = dot(lightDir, vNormal);

            #ifdef RENDER_TEXTURED
                vLit = 1.0;
            #else
                vLit = geoNoL;

                #if defined RENDER_TERRAIN && defined FOLIAGE_UP
                    if (mc_Entity.x >= 10001.0 && mc_Entity.x <= 10004.0)
                        vLit = dot(lightDir, gbufferModelView[1].xyz);
                #endif
            #endif
        #else
            geoNoL = 1.0;
            vLit = 1.0;
        #endif

        #if defined WORLD_SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                shadowTile = -1;
            #endif

            float viewDist = 1.0 + length(viewPos.xyz);

            vec3 shadowViewPos = viewPos.xyz;
            shadowViewPos += vNormal * viewDist * SHADOW_NORMAL_BIAS * max(1.0 - geoNoL, 0.0);

            vec3 shadowLocalPos = (gbufferModelViewInverse * vec4(shadowViewPos, 1.0)).xyz;

            ApplyShadows(shadowLocalPos);
        #endif

        gl_Position = gl_ProjectionMatrix * viewPos;
    }
#endif

#ifdef RENDER_FRAG
    #if (defined RENDER_GBUFFER && !defined SHADOW_BLUR) || defined RENDER_COMPOSITE
        float GetFogFactor(const in float dist, const in float start, const in float end, const in float density) {
            float distFactor = dist >= end ? 1.0 : smoothstep(start, end, dist);
            return saturate(pow(distFactor, density));
        }

        float GetVanillaFogFactor(const in vec3 localPos) {
            if (fogStart > far) return 0.0;

            vec3 fogPos = localPos;
            if (fogShape == 1)
                fogPos.y = 0.0;

            float viewDist = length(fogPos);

            return GetFogFactor(viewDist, fogStart, fogEnd, 1.0);
        }

        void ApplyFog(inout vec4 color, const in vec3 localPos) {
            float fogF = GetVanillaFogFactor(localPos);
            vec3 fogCol = RGBToLinear(fogColor);

            color.rgb = mix(color.rgb, fogCol, fogF);

            if (color.a > alphaTestRef)
                color.a = mix(color.a, 1.0, fogF);
        }
    #endif

    #if defined RENDER_GBUFFER && !defined RENDER_CLOUDS
        vec4 GetColor() {
            vec4 color = texture(gtexture, texcoord);

            #if !defined RENDER_WATER && !defined RENDER_HAND_WATER
                if (color.a < alphaTestRef) {
                    discard;
                    return vec4(0.0);
                }
            #endif

            color.rgb *= glcolor.rgb;

            #if defined WORLD_SHADOW_ENABLED && SHADOW_TYPE == SHADOW_TYPE_CASCADED && defined DEBUG_CASCADE_TINT && defined SHADOW_BLUR
                color.rgb = RGBToLinear(color.rgb);
                color.rgb *= 1.0 - LOD_TINT_FACTOR * (1.0 - GetShadowTileColor(shadowTile));
                color.rgb = LinearToRGB(color.rgb);
            #endif

            return color;
        }

        #if SHADOW_COLORS == SHADOW_COLOR_ENABLED
            vec3 GetFinalShadowColor() {
                vec3 shadowColor = vec3(1.0);

                #if defined WORLD_SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                        int tile = GetShadowCascade(shadowPos, ShadowPCFSize);

                        if (tile >= 0)
                            shadowColor = GetShadowColor(shadowPos[tile], tile);
                    #else
                        shadowColor = GetShadowColor(shadowPos);
                    #endif
                #endif

                return mix(shadowColor * max(vLit, 0.0), vec3(1.0), SHADOW_BRIGHTNESS);
            }
        #else
            float GetFinalShadowFactor() {
                float shadow = 1.0;

                #if defined WORLD_SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                        int tile = GetShadowCascade(shadowPos, ShadowPCFSize);

                        if (tile >= 0)
                            shadow = GetShadowFactor(shadowPos[tile], tile);
                    #else
                        shadow = GetShadowFactor(shadowPos);
                    #endif
                #endif

                return shadow * max(vLit, 0.0);
            }
        #endif
    #endif

    #if (defined RENDER_GBUFFER && !defined SHADOW_BLUR) || defined RENDER_COMPOSITE
        vec4 GetFinalLighting(const in vec4 color, const in vec3 shadowColor, const in vec3 localPos, const in vec2 lmcoord, const in float occlusion) {
            vec3 albedo = RGBToLinear(color.rgb);

            #if defined WORLD_SHADOW_ENABLED && SHADOW_TYPE == SHADOW_TYPE_CASCADED && defined DEBUG_CASCADE_TINT && !defined RENDER_CLOUDS && !defined RENDER_COMPOSITE
                albedo *= 1.0 - LOD_TINT_FACTOR * (1.0 - GetShadowTileColor(shadowTile));
            #endif

            #ifdef IS_IRIS
                vec3 blockLight = textureLod(texLightMap, vec2(lmcoord.x, 1.0/32.0), 0).rgb;
                vec3 skyLight = textureLod(texLightMap, vec2(1.0/32.0, lmcoord.y), 0).rgb;
            #elif defined RENDER_COMPOSITE //|| defined RENDER_CLOUDS
                vec3 blockLight = textureLod(colortex3, vec2(lmcoord.x, 1.0/32.0), 0).rgb;
                vec3 skyLight = textureLod(colortex3, vec2(1.0/32.0, lmcoord.y), 0).rgb;
            #else
                vec3 blockLight = textureLod(lightmap, vec2(lmcoord.x, 1.0/32.0), 0).rgb;
                vec3 skyLight = textureLod(lightmap, vec2(1.0/32.0, lmcoord.y), 0).rgb;
            #endif

            blockLight = RGBToLinear(blockLight);
            skyLight = RGBToLinear(skyLight);

            skyLight *= 1.0 - blindness;

            vec3 ambient = albedo.rgb * skyLight * occlusion * SHADOW_BRIGHTNESS;
            vec3 diffuse = albedo.rgb * (blockLight + skyLight * shadowColor) * (1.0 - SHADOW_BRIGHTNESS);
            vec4 final = vec4(ambient + diffuse, color.a);

            ApplyFog(final, localPos);

            final.rgb = LinearToRGB(final.rgb);
            return final;
        }
    #endif
#endif

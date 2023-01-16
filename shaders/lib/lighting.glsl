#ifdef RENDER_VERTEX
	void BasicVertex() {
		vec4 pos = gl_Vertex;

		#if defined RENDER_TERRAIN && defined ENABLE_WAVING
			if (mc_Entity.x >= 10001.0 && mc_Entity.x <= 10004.0)
				pos.xyz += GetWavingOffset();
		#endif

		vec4 viewPos = gl_ModelViewMatrix * pos;

		vPos = viewPos.xyz;// / viewPos.w;

		vNormal = gl_Normal;

		#ifdef RENDER_TEXTURED
			// TODO: extract billboard direction from view matrix?
			vNormal = normalize(gl_NormalMatrix * vNormal);
		#else
			vNormal = normalize(gl_NormalMatrix * vNormal);
		#endif

		vec3 lightDir = normalize(shadowLightPosition);
		geoNoL = dot(lightDir, vNormal);

		#ifdef RENDER_TEXTURED
			vLit = 1.0;
		#else
			#ifdef SHADOW_ENABLED
				vec3 lightNormal = vNormal;

				#if defined FOLIAGE_UP && defined RENDER_TERRAIN
					if (mc_Entity.x >= 10001.0 && mc_Entity.x <= 10004.0)
						lightNormal = gbufferModelView[1].xyz;
				#endif

				vLit = dot(lightDir, lightNormal);
			#else
				vLit = geoNoL;
			#endif
		#endif

		#if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
			if (geoNoL > 0.0) {
				float viewDist = length(viewPos);
				float normalBias = viewDist * SHADOW_NORMAL_BIAS;

	        	vec3 shadowViewPos = viewPos.xyz + vNormal * normalBias * max(1.0 - geoNoL, 0.0);
				vec3 shadowLocalPos = (gbufferModelViewInverse * vec4(shadowViewPos, 1.0)).xyz;

				ApplyShadows(shadowLocalPos);
			}
		#endif

		gl_Position = gl_ProjectionMatrix * viewPos;
	}
#endif

#ifdef RENDER_FRAG
	void ApplyFog(inout vec4 color) {
		vec3 fogPos = vPos;
		//if (fogShape == 1) fogPos.z = 0.0;
		float fogF = clamp((length(fogPos) - fogStart) / (fogEnd - fogStart), 0.0, 1.0);

		vec3 fogCol = RGBToLinear(fogColor);
		color.rgb = mix(color.rgb, fogCol, fogF);

		if (color.a > alphaTestRef)
			color.a = mix(color.a, 1.0, fogF);
	}

	vec4 BasicLighting() {
		vec4 albedo = texture(gtexture, texcoord) * glcolor;
		albedo.rgb = RGBToLinear(albedo.rgb);

		#if !defined RENDER_WATER && !defined RENDER_HAND_WATER
			if (albedo.a < alphaTestRef) {
				discard;
				return vec4(0.0);
			}
		#endif

		float shadow = 1.0;
		vec3 lightColor = vec3(1.0);

		#if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
			if (geoNoL > 0.0) {
				shadow = GetShadowing(shadowPos);

				#if SHADOW_COLORS == 1
					vec3 shadowColor = GetShadowColor(shadowPos);

					shadowColor = mix(vec3(1.0), shadowColor, shadow);

					//also make colors less intense when the block light level is high.
					//shadowColor = mix(shadowColor, vec3(1.0), lm.x);

					lightColor *= shadowColor;
				#endif
			}
		#endif

		vec3 lightFinal = lightColor * mix(max(vLit, 0.0) * shadow, 1.0, SHADOW_BRIGHTNESS);

		vec4 final = albedo;
		final.rgb *= lightFinal;
		return final;
	}
#endif

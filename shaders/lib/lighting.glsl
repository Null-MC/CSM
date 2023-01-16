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

		#ifdef RENDER_TERRAIN
			if (mc_Entity.x >= 10001.0 && mc_Entity.x <= 10004.0)
				vNormal = vec3(0.0, 1.0, 0.0);
		#endif

		#ifdef RENDER_TEXTURED
			// TODO: extract billboard direction from view matrix?
			vNormal = normalize(gl_NormalMatrix * vNormal);
		#else
			vNormal = normalize(gl_NormalMatrix * vNormal);
		#endif

		#ifdef SHADOW_ENABLED
			#ifdef RENDER_TEXTURED
				geoNoL = 1.0;
			#else
				vec3 lightDir = normalize(shadowLightPosition);
				geoNoL = dot(lightDir, vNormal);

				// #if defined RENDER_TERRAIN && defined SHADOW_EXCLUDE_FOLIAGE
				// 	//when SHADOW_EXCLUDE_FOLIAGE is enabled, act as if foliage is always facing towards the sun.
				// 	//in other words, don't darken the back side of it unless something else is casting a shadow on it.
				// 	if (mc_Entity.x >= 10000.0 && mc_Entity.x <= 10004.0) geoNoL = 1.0;
				// #endif
			#endif

			#if SHADOW_TYPE != SHADOW_TYPE_NONE && !defined RENDER_SHADOW && defined SHADOW_ENABLED
            	vec3 shadowViewPos = viewPos.xyz + vNormal * SHADOW_NORMAL_BIAS;
				vec3 shadowLocalPos = (gbufferModelViewInverse * vec4(shadowViewPos, 1.0)).xyz;

				ApplyShadows(shadowLocalPos);
			#endif
		#else
			geoNoL = 1.0;
		#endif

		gl_Position = gl_ProjectionMatrix * viewPos;
	}
#endif

#ifdef RENDER_FRAG
	const float shininess = 16.0;

	vec4 ApplyLighting(const in vec4 albedo, const in vec3 lightColor, const in vec2 lm) {
		vec3 lmValue = texture(lightmap, lm).rgb;
		lmValue = RGBToLinear(lmValue);
		vec4 final = albedo;

		#if LIGHTING_TYPE == 1 || LIGHTING_TYPE == 2
			// [1] Phong & [2] Blinn-Phong
			vec3 normal = normalize(vNormal);
			vec3 viewDir = normalize(-vPos);
			vec3 lightDir = normalize(shadowLightPosition);

			float specular;
			#if LIGHTING_TYPE == 2
				// Blinn-Phong
				vec3 halfDir = normalize(lightDir + viewDir);
				float specAngle = max(dot(halfDir, normal), 0.0);
				specular = pow(specAngle, shininess);
			#else
				// Phong
				vec3 reflectDir = reflect(-lightDir, normal);
				float specAngle = max(dot(reflectDir, viewDir), 0.0);
				specular = pow(specAngle, shininess * 0.25);
			#endif

			vec3 ambientColor = lmValue * SHADOW_BRIGHTNESS;

			final.rgb *= ambientColor + lightColor * (geoNoL + specular);
		#else
			// [0] None
			final.rgb *= lmValue * lightColor;
		#endif

		return final;
	}

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

		vec3 lightColor = vec3(1.0);
		vec2 lm = lmcoord;

		float dark = lm.y * SHADOW_BRIGHTNESS * (31.0 / 32.0) + (1.0 / 32.0);

		if (geoNoL >= EPSILON && lm.y > 1.0/32.0) {
			#if SHADOW_TYPE != 0 && defined SHADOW_ENABLED
				float shadow = GetShadowing(shadowPos);

				#if SHADOW_COLORS == 1
					vec3 shadowColor = GetShadowColor(shadowPos);

					shadowColor = mix(vec3(1.0), shadowColor, shadow);

					//also make colors less intense when the block light level is high.
					shadowColor = mix(shadowColor, vec3(1.0), lm.x);

					lightColor *= shadowColor;
				#endif

				//surface is in direct sunlight. increase light level.
				#ifdef RENDER_TEXTURED
					float lightMax = 31.0 / 32.0;
				#else
					float lightMax = mix(dark, 31.0 / 32.0, sqrt(geoNoL));
				#endif

				lightMax = max(lightMax, lm.y);
				lm.y = mix(dark, lightMax, shadow);
			#else
				#ifdef RENDER_TEXTURED
					lm.y = 31.0 / 32.0;
				#else
					lm.y = mix(dark, 31.0 / 32.0, sqrt(geoNoL));
				#endif
			#endif
		}
		else {
			lm.y = dark;
		}

		return ApplyLighting(albedo, lightColor, lm);
	}
#endif

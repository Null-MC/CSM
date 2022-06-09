#ifdef RENDER_VERTEX
	void BasicVertex() {
		vec4 pos = gl_Vertex;

		#if defined RENDER_TERRAIN && defined ENABLE_WAVING
			if (mc_Entity.x >= 10001.0 && mc_Entity.x <= 10004.0)
				pos.xyz += GetWavingOffset();
		#endif

		vec4 viewPos = gl_ModelViewMatrix * pos;

		vPos = viewPos.xyz / viewPos.w;

		#ifdef RENDER_TEXTURED
			// extract billboard direction from view matrix?
			vNormal = normalize(gl_NormalMatrix * gl_Normal);
		#else
			vNormal = normalize(gl_NormalMatrix * gl_Normal);
		#endif

		#if SHADOW_TYPE != 0 && !defined RENDER_SHADOW
			ApplyShadows(viewPos);
		#endif

		gl_Position = gl_ProjectionMatrix * viewPos;
	}
#endif

#ifdef RENDER_FRAG
	const float shininess = 16.0;

	uniform float screenBrightness;
	uniform vec3 upPosition;

	uniform int fogMode;
	uniform float fogStart;
	uniform float fogEnd;
	uniform int fogShape;
	uniform vec3 fogColor;
	uniform vec3 skyColor;


	vec4 ApplyLighting(const in vec4 albedo, const in vec3 lightColor, const in vec2 lm) {
		vec3 lmValue = texture2D(lightmap, lm).rgb * screenBrightness;
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
		color = mix(color, vec4(fogCol, 1.0), fogF);
	}

	vec4 BasicLighting() {
		vec4 texColor = texture2D(texture, texcoord) * glcolor;
		vec3 lightColor = vec3(1.0);
		vec2 lm = lmcoord;

		vec4 albedo = texColor;
		albedo.rgb = RGBToLinear(albedo.rgb);

		#if SHADOW_TYPE != 0
			vec3 upDir = normalize(upPosition);
			vec3 lightDir = normalize(shadowLightPosition);
			float shadowMul = max(dot(upDir, lightDir), 0.0) * SHADOW_BRIGHTNESS + 0.02;

			if (geoNoL > 0.0) {
				vec3 shadowColor;
				float shadow = GetShadowing(shadowColor);

				//also make colors less intense when the block light level is high.
				shadowColor = mix(shadowColor, vec3(1.0), lm.x);
				lightColor *= shadowColor;

				if (shadow > 0.5) {
					//surface is in direct sunlight. increase light level.
					#ifdef RENDER_TEXTURED
						lm.y = 31.0 / 32.0;
					#else
						lm.y = mix(shadowMul, 1.0, sqrt(geoNoL)) * (31.0 / 32.0);
					#endif
				}
				else {
					lm.y = shadowMul;
				}
			}
			else {
				lm.y = shadowMul;
			}
		#endif

		vec4 final = ApplyLighting(albedo, lightColor, lm);
		ApplyFog(final);

		final.rgb = LinearToRGB(final.rgb);
		return final;
	}
#endif

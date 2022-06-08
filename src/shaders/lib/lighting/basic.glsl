#ifdef RENDER_VERTEX
	void BasicVertex() {
		vec4 pos = gl_Vertex;

		#if defined RENDER_TERRAIN && defined ENABLE_WAVING
			if (mc_Entity.x == 10001.0)
				pos.xyz += GetWavingOffset();
		#endif

		vec4 viewPos = gl_ModelViewMatrix * pos;

		#if SHADOW_TYPE != 0 && !defined RENDER_SHADOW
			ApplyShadows(viewPos);
		#endif

		gl_Position = gl_ProjectionMatrix * viewPos;
	}
#endif

#ifdef RENDER_FRAG
	vec4 BasicLighting() {
		vec4 texColor = texture2D(texture, texcoord) * glcolor;
		vec2 lm = lmcoord;

		#if SHADOW_TYPE != 0
			if (geoNoL > 0.0) texColor.rgb *= GetShadowColor(lm);
		#endif

		texColor.rgb *= texture2D(lightmap, lm).rgb;

		return texColor;
	}
#endif

// TODO: PCSS + PCF

float PCF(const in vec2 texcoord, const in float depth, const in int radius) {
	float shadowPixelSize = (1.0 / shadowMapResolution);// * 0.5;

	float texDepth;
	int sampleCount = 0;
	float shadow = 0.0;
	for (int y = -radius; y <= radius; y++) {
		for (int x = -radius; x <= radius; x++) {
			vec2 t = texcoord + vec2(x, y) * shadowPixelSize;

			#if SHADOW_COLORS == 0
				//for normal shadows, only consider the closest thing to the sun,
				//regardless of whether or not it's opaque.
				texDepth = texture2D(shadowtex0, t).r;
			#else
				//for invisible and colored shadows, first check the closest OPAQUE thing to the sun.
				texDepth = texture2D(shadowtex1, t).r;
			#endif

			//if (texDepth + EPSILON >= 1.0) continue;

			//shadow += depth > texDepth ? 1.0 : 0.0;
			shadow += step(texDepth, depth);
			sampleCount++;
		}
	}

	if (sampleCount < 1) return 0.0;
	return clamp(shadow / sampleCount, 0.0, 1.0);
}

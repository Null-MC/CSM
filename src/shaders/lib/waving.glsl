vec3 hash33(in vec3 p3) {
    p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);
}

vec3 GetWavingOffset() {
	// #ifdef RENDER_SHADOW
	// 	vec3 shadowViewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
	// 	vec3 playerPos = (shadowModelViewInverse * vec4(shadowViewPos, 1.0)).xyz;
	// 	vec3 worldPos = playerPos + cameraPosition;
	// #else
	// 	vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
	// 	vec4 playerPos = gbufferModelViewInverse * viewPos;
	// 	vec3 worldPos = playerPos.xyz + cameraPosition;
	// #endif
	vec3 worldPos = vaPosition.xyz + chunkOffset + cameraPosition;

	//vec3 hash = hash33(worldPos) * 2.0 * PI + frameTimeCounter;
	vec3 hash = mod(hash33(worldPos) * 2.0 * PI + frameTimeCounter, 2.0 * PI);
	return sin(hash) * 0.06;
}

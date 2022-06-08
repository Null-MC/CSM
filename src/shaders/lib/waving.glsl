vec3 hash33(in vec3 p3) {
    p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);
}

vec3 noise(vec3 p) {
    vec3 f = fract(p);
    p = floor(p);
    return mix(
        mix(
            mix(
                hash33(p + vec3(0, 0, 0)),
                hash33(p + vec3(0, 0, 1)),
                f.z
            ),
            mix(
                hash33(p + vec3(0, 1, 0)),
                hash33(p + vec3(0, 1, 1)),
                f.z
            ),
            f.y
        ),
        mix(
            mix(
                hash33(p + vec3(1, 0, 0)),
                hash33(p + vec3(1, 0, 1)),
                f.z
            ),
            mix(
                hash33(p + vec3(1, 1, 0)),
                hash33(p + vec3(1, 1, 1)),
                f.z
            ),
            f.y
        ),
        f.x
    );
}

vec3 fbm(vec3 pos) {
    vec3 val = vec3(0);
    float weight = 0.5;
    float totalWeight = 0.0;
    float frequency = 0.1;
    for (int i = 0; i < 8; i++) {
        val += noise(pos * frequency) * weight;
        totalWeight += weight;
        weight /= 2.0;
        frequency *= 2.0;
    }
    return val / totalWeight;
}

vec3 GetWavingOffset() {
	vec3 worldPos = vaPosition.xyz + chunkOffset + cameraPosition;
	vec3 hash = mod(fbm(worldPos) * 2.0 * PI + frameTimeCounter, 2.0 * PI);
	return sin(hash) * 0.06;
}

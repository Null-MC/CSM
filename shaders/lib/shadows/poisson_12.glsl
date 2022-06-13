#define POISSON_SAMPLES 12

const vec2 poissonDisk[POISSON_SAMPLES] = vec2[](
	vec2(-0.326212, -0.40581),
	vec2(-0.840144, -0.07358),
	vec2(-0.695914, 0.457137),
	vec2(-0.203345, 0.620716),
	vec2(  0.96234,-0.194983),
	vec2( 0.473434,-0.480026),
	vec2( 0.519456, 0.767022),
	vec2( 0.185461,-0.893124),
	vec2( 0.507431, 0.064425),
	vec2(  0.89642, 0.412458),
	vec2( -0.32194,-0.932615),
	vec2(-0.791559, -0.59771));

vec2 GetPoissonOffset(const in int index) {
	return poissonDisk[index];
}

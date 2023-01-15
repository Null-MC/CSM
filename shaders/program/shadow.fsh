#define RENDER_SHADOW
#define RENDER_FRAG

#include "/lib/common.glsl"
#include "/lib/constants.glsl"

varying vec2 gTexcoord;
varying vec4 gColor;

#if SHADOW_TYPE == 3
	flat varying vec2 gShadowTilePos;
#endif

uniform sampler2D texture;


void main() {
	#if SHADOW_TYPE == 3
		vec2 p = gl_FragCoord.xy / shadowMapSize - gShadowTilePos;
		if (p.x < 0 || p.x >= 0.5 || p.y < 0 || p.y >= 0.5) discard;
	#endif

	vec4 color = texture2D(texture, gTexcoord) * gColor;

	gl_FragData[0] = color;
}

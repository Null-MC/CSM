#define RENDER_SHADOW
#define RENDER_FRAG

#include "/lib/common.glsl"
#include "/lib/constants.glsl"

in vec2 gTexcoord;
in vec4 gColor;

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
	flat in vec2 gShadowTilePos;
#endif

uniform sampler2D gtexture;

uniform int renderStage;

#if MC_VERSION >= 11700
	uniform float alphaTestRef;
#endif


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;

void main() {
	#if SHADOW_TYPE == 3
		vec2 p = gl_FragCoord.xy / shadowMapSize - gShadowTilePos;
		//if (p.x < 0 || p.x >= 0.5 || p.y < 0 || p.y >= 0.5) discard;
		if (clamp(p, vec2(0.0), vec2(0.5)) != p) discard;
	#endif

	vec4 color = texture(gtexture, gTexcoord) * gColor;

	if (renderStage != MC_RENDER_STAGE_TERRAIN_TRANSLUCENT) {
		if (color.a < alphaTestRef) {
			discard;
			return;
		}
	}

	outColor0 = color;
}

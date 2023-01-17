#define RENDER_CLOUDS
#define RENDER_GBUFFER
#define RENDER_FRAG

#include "/lib/common.glsl"
#include "/lib/constants.glsl"

varying vec2 texcoord;
varying vec4 glcolor;

uniform sampler2D gtexture;

uniform float alphaTestRef;


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;

void main() {
	vec4 color = texture(gtexture, texcoord) * glcolor;

	if (color.a < alphaTestRef) discard;

	outColor0 = color;
}

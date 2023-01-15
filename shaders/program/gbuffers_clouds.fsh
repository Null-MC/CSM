#define RENDER_CLOUDS
#define RENDER_FRAG

#include "/lib/common.glsl"
#include "/lib/constants.glsl"

varying vec2 texcoord;
varying vec4 glcolor;

uniform sampler2D texture;


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;

void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;

	outColor0 = color;
}

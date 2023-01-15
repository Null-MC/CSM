#define RENDER_CLOUDS
#define RENDER_FRAG

#include "/lib/common.glsl"
#include "/lib/constants.glsl"

varying vec2 texcoord;
varying vec4 glcolor;

uniform sampler2D texture;


void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;

	/* DRAWBUFFERS:0 */
	gl_FragData[0] = color;
}

#define RENDER_BASIC
#define RENDER_FRAG

#include "/lib/common.glsl"
#include "/lib/constants.glsl"

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;

uniform sampler2D lightmap;
uniform sampler2D texture;


void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;
	color *= texture2D(lightmap, lmcoord);

	/* DRAWBUFFERS:0 */
	gl_FragData[0] = color;
}

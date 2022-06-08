#version 120

uniform float frameTimeCounter;
uniform sampler2D gcolor;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;

varying vec2 texcoord;

#include "lib/common.glsl"


void main() {
	vec3 color = texture2D(DEBUG_SHADOW_BUFFER, texcoord).rgb;

/* DRAWBUFFERS:0 */
	gl_FragData[0] = vec4(color, 1.0); //gcolor
}

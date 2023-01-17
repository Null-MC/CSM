#define RENDER_DEFERRED
#define RENDER_FRAG

#include "/lib/common.glsl"
#include "/lib/constants.glsl"

in vec2 texcoord;

uniform sampler2D depthtex0;
uniform sampler2D colortex0;
uniform sampler2D colortex1;

uniform mat4 gbufferProjectionInverse;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

uniform vec3 upPosition;
uniform vec3 skyColor;
uniform int fogMode;
uniform float fogStart;
uniform float fogEnd;
uniform int fogShape;
uniform vec3 fogColor;

#if MC_VERSION >= 11700
	uniform float alphaTestRef;
#endif

#include "/lib/depth.glsl"
#include "/lib/lighting.glsl"
#include "/lib/bilateral_gaussian.glsl"


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;

void main() {
	ivec2 iTex = ivec2(gl_FragCoord.xy);
	vec4 color = texelFetch(colortex0, iTex, 0);
	float depth = texelFetch(depthtex0, iTex, 0).r;

	vec2 viewSize = vec2(viewWidth, viewHeight);
	float linearDepth = linearizeDepthFast(depth, near, far);
	vec3 lightColor = BilateralGaussianDepthBlurRGB_5x(texcoord, colortex1, viewSize, depthtex0, viewSize, linearDepth, 0.2);

	vec3 clipPos = vec3(gl_FragCoord.xy / viewSize, depth) * 2.0 - 1.0;
	vec3 viewPos = (gbufferProjectionInverse * vec4(clipPos, 1.0)).xyz;
	vec4 final = GetFinalLighting(color, lightColor, viewPos);

	outColor0 = final;
}

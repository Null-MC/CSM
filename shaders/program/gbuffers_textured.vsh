#define RENDER_TEXTURED
#define RENDER_VERTEX

#include "/lib/common.glsl"
#include "/lib/constants.glsl"

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 vPos;
out vec3 vNormal;
out float geoNoL;

#ifdef SHADOW_ENABLED
	#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
		out vec3 shadowPos[4];
		flat out int shadowTile;

		#ifndef IS_IRIS
			flat out vec2 shadowProjectionSize[4];
			flat out float cascadeSize[4];
		#endif
	#elif SHADOW_TYPE != SHADOW_TYPE_NONE
		out vec3 shadowPos;
	#endif
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

#ifdef SHADOW_ENABLED
	uniform mat4 shadowModelView;
	uniform mat4 shadowProjection;
	uniform vec3 shadowLightPosition;
	uniform float far;

	#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
		attribute vec3 at_midBlock;

        #ifndef IS_IRIS
            uniform mat4 gbufferPreviousModelView;
            uniform mat4 gbufferPreviousProjection;
        #endif

		uniform mat4 gbufferProjection;
		uniform float near;
	#endif
#endif

#ifdef SHADOW_ENABLED
	#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
		#include "/lib/shadows/csm.glsl"
	#elif SHADOW_TYPE != SHADOW_TYPE_NONE
		#include "/lib/shadows/basic.glsl"
	#endif
#endif

#include "/lib/lighting.glsl"


void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;

	BasicVertex();
}

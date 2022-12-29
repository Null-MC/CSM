varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec3 vPos;
varying vec3 vNormal;
varying float geoNoL;

in vec4 mc_Entity;
in vec3 vaPosition;
in vec3 at_midBlock;

#ifdef SHADOW_ENABLED
	#if SHADOW_TYPE == 3
		varying vec4 shadowPos[4];
		varying vec2 shadowProjectionSize[4];
		flat varying vec3 shadowTileColor;
	#elif SHADOW_TYPE != 0
		varying vec4 shadowPos;
	#endif
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;

#if MC_VERSION >= 11700
	uniform vec3 chunkOffset;
#endif

#include "/lib/waving.glsl"

#ifdef SHADOW_ENABLED
	uniform mat4 shadowModelView;
	uniform mat4 shadowProjection;
	uniform vec3 shadowLightPosition;
	uniform float far;

	#if SHADOW_TYPE == 3
        #ifdef IS_OPTIFINE
            uniform mat4 gbufferPreviousModelView;
            uniform mat4 gbufferPreviousProjection;
        #endif

		uniform mat4 gbufferProjection;
		uniform float near;

		#include "/lib/shadows/csm.glsl"
		#include "/lib/shadows/csm_render.glsl"
	#elif SHADOW_TYPE != 0
		#include "/lib/shadows/basic.glsl"
	#endif
#endif

#include "/lib/lighting/basic.glsl"


void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;

	BasicVertex();
}

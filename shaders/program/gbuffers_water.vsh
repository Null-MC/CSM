varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec3 vPos;
varying vec3 vNormal;
varying float geoNoL;

in vec4 mc_Entity;
in vec3 vaPosition;
in vec3 at_midBlock;

#if defined SHADOW_ENABLED && SHADOW_TYPE != 0
	varying vec3 shadowPos;

	#if SHADOW_TYPE == 3
		flat varying int shadowTile;
		flat varying vec3 shadowTileColor;
		//flat varying float cascadeSize[4];
		flat varying vec2 shadowProjectionSize[4];
	#endif
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;

#if MC_VERSION >= 11700 && defined IS_OPTIFINE
	uniform vec3 chunkOffset;
#endif

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
	#endif
#endif

#include "/lib/waving.glsl"

#ifdef SHADOW_ENABLED
	#if SHADOW_TYPE == 3
		#include "/lib/shadows/csm.glsl"
	#elif SHADOW_TYPE != 0
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
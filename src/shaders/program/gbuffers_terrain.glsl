#define RENDER_TERRAIN

#include "/lib/common.glsl"

#ifdef RENDER_VERTEX
	in vec4 mc_Entity;
	in vec3 vaPosition;

	uniform mat4 gbufferModelView;
	uniform mat4 gbufferModelViewInverse;
	uniform mat4 shadowModelView;
	uniform mat4 shadowProjection;
	uniform vec3 shadowLightPosition;
	uniform float frameTimeCounter;
	uniform vec3 cameraPosition;
	uniform vec3 chunkOffset;

	out vec2 lmcoord;
	out vec2 texcoord;
	out vec4 glcolor;
	flat out float geoNoL;

	#include "/lib/waving.glsl"

	#if SHADOW_TYPE == 3
		attribute vec3 at_midBlock;

		uniform float near;
		uniform float far;

		out vec3 shadowPos[4];
		flat out vec3 shadowTileColor;

		#include "/lib/shadows/csm.glsl"
	#elif SHADOW_TYPE != 0
		out vec3 shadowPos;

		#include "/lib/shadows/basic.glsl"
	#endif

	#include "/lib/lighting/basic.glsl"


	void main() {
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
		glcolor = gl_Color;

		BasicVertex();
	}
#endif

#ifdef RENDER_FRAG
	uniform sampler2D lightmap;
	uniform sampler2D shadowcolor0;
	uniform sampler2D shadowtex0;
	uniform sampler2D shadowtex1;
	uniform sampler2D texture;

	in vec2 lmcoord;
	in vec2 texcoord;
	in vec4 glcolor;
	flat in float geoNoL;

	//fix artifacts when colored shadows are enabled
	const bool shadowcolor0Nearest = true;
	const bool shadowtex0Nearest = true;
	const bool shadowtex1Nearest = true;

	#if SHADOW_TYPE == 3
		in vec3 shadowPos[4];
		flat in vec3 shadowTileColor;

		#include "/lib/shadows/csm.glsl"
	#elif SHADOW_TYPE != 0
		in vec3 shadowPos;

		#include "/lib/shadows/basic.glsl"
	#endif

	#include "/lib/lighting/basic.glsl"


	void main() {
		vec4 color = BasicLighting();

		#ifdef DEBUG_CASCADE_TINT
			color.rgb *= 1.0 - LOD_TINT_FACTOR * (1.0 - shadowTileColor);
		#endif

	/* DRAWBUFFERS:0 */
		gl_FragData[0] = color; //gcolor
	}
#endif

#define RENDER_ENTITIES

#include "/lib/common.glsl"

#ifdef RENDER_VERTEX
	uniform mat4 gbufferModelView;
	uniform mat4 gbufferModelViewInverse;
	uniform mat4 shadowModelView;
	uniform mat4 shadowProjection;
	uniform vec3 shadowLightPosition;

	out vec2 lmcoord;
	out vec2 texcoord;
	out vec4 glcolor;
	flat out vec3 vPos;
	flat out vec3 vNormal;
	flat out float geoNoL;

	#if SHADOW_TYPE == 3
		attribute vec3 at_midBlock;

		uniform int entityId;
		uniform float near;
		uniform float far;

		out vec3 shadowPos[4];
		flat out vec3 shadowTileColor;

		#include "/lib/shadows/csm.glsl"
		#include "/lib/shadows/csm_render.glsl"
	#elif SHADOW_TYPE != 0
		out vec3 shadowPos;

		#include "/lib/shadows/basic.glsl"
	#endif


	void main() {
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
		glcolor = gl_Color;
		
		vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;

		#if SHADOW_TYPE != 0
			ApplyShadows(viewPos);
		#endif

		//use consistent transforms for entities and hand so that armor glint doesn't have z-fighting issues.
		gl_Position = gl_ProjectionMatrix * viewPos;
	}
#endif

#ifdef RENDER_FRAG
	uniform sampler2D texture;
	uniform sampler2D lightmap;
	uniform sampler2D shadowcolor0;
	uniform sampler2D shadowtex0;
	uniform sampler2D shadowtex1;
	
	uniform vec3 shadowLightPosition;

	in vec2 lmcoord;
	in vec2 texcoord;
	in vec4 glcolor;
	flat in vec3 vPos;
	flat in vec3 vNormal;
	flat in float geoNoL;

	//fix artifacts when colored shadows are enabled
	const bool shadowcolor0Nearest = true;
	const bool shadowtex0Nearest = true;
	const bool shadowtex1Nearest = true;

	#if SHADOW_TYPE == 3
		in vec3 shadowPos[4];
		flat in vec3 shadowTileColor;

		#include "/lib/shadows/csm.glsl"
		#include "/lib/shadows/csm_render.glsl"
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

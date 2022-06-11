#define RENDER_TERRAIN

#include "/lib/common.glsl"

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
flat varying vec3 vPos;
flat varying vec3 vNormal;
flat varying float geoNoL;

#ifndef WORLD_END
	#if SHADOW_TYPE == 3
		varying vec3 shadowPos[4];
		flat varying int shadowTile;
		flat varying vec3 shadowTileColor;
	#elif SHADOW_TYPE != 0
		varying vec3 shadowPos;
	#endif
#endif

#ifdef RENDER_VERTEX
	in vec4 mc_Entity;
	in vec3 vaPosition;
	in vec3 at_midBlock;

	uniform mat4 gbufferModelView;
	uniform mat4 gbufferModelViewInverse;
	uniform float frameTimeCounter;
	uniform vec3 cameraPosition;
	uniform vec3 chunkOffset;

	#include "/lib/waving.glsl"

	#ifndef WORLD_END
		uniform mat4 shadowModelView;
		uniform mat4 shadowProjection;
		uniform vec3 shadowLightPosition;
		uniform float far;

		#if SHADOW_TYPE == 3
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
#endif

#ifdef RENDER_FRAG
	uniform sampler2D texture;
	uniform sampler2D lightmap;

	#ifndef WORLD_END
		uniform sampler2D shadowcolor0;
		uniform sampler2D shadowtex0;
		uniform sampler2D shadowtex1;
		
		uniform vec3 shadowLightPosition;

		//fix artifacts when colored shadows are enabled
		const bool shadowcolor0Nearest = true;
		const bool shadowtex0Nearest = true;
		const bool shadowtex1Nearest = true;
		
		#if SHADOW_TYPE == 3
			#include "/lib/shadows/csm.glsl"
			#include "/lib/shadows/csm_render.glsl"
		#elif SHADOW_TYPE != 0
			#include "/lib/shadows/basic.glsl"
		#endif
	#endif

	#include "/lib/lighting/basic.glsl"


	void main() {
		vec4 color = BasicLighting();

		#if defined DEBUG_CASCADE_TINT && !defined WORLD_END
			color.rgb *= 1.0 - LOD_TINT_FACTOR * (1.0 - shadowTileColor);
		#endif

		ApplyFog(color);

		color.rgb = LinearToRGB(color.rgb);

	/* DRAWBUFFERS:0 */
		gl_FragData[0] = color; //gcolor
	}
#endif
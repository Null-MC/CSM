#define RENDER_TEXTURED

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec3 vPos;
varying vec3 vNormal;
varying float geoNoL;

#ifndef WORLD_END
	#if SHADOW_TYPE == 3
		varying vec3 shadowPos[4]; //normals don't exist for particles
		varying vec2 shadowProjectionScale[4];
	#elif SHADOW_TYPE != 0
		varying vec3 shadowPos; //normals don't exist for particles
	#endif
#endif

#ifdef RENDER_VERTEX
	uniform mat4 gbufferModelView;
	uniform mat4 gbufferModelViewInverse;

	#ifndef WORLD_END
		uniform mat4 shadowModelView;
		uniform mat4 shadowProjection;
		uniform vec3 shadowLightPosition;
		uniform float far;

		#if SHADOW_TYPE == 3
			attribute vec3 at_midBlock;

			uniform mat4 gbufferPreviousModelView;
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

		#include "/lib/shadows/poisson_36.glsl"

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

		ApplyFog(color);

		color.rgb = LinearToRGB(color.rgb);

		/* DRAWBUFFERS:0 */
		gl_FragData[0] = color; //gcolor
	}
#endif

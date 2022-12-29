varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec3 vPos;
varying vec3 vNormal;
varying float geoNoL;

#ifdef SHADOW_ENABLED
	#if SHADOW_TYPE == 3
		varying vec4 shadowPos[4];
		flat varying vec3 shadowTileColor;
		varying vec2 shadowProjectionSize[4];
	#elif SHADOW_TYPE != 0
		varying vec4 shadowPos;
	#endif
#endif

uniform sampler2D texture;
uniform sampler2D lightmap;

#ifdef SHADOW_ENABLED
	uniform sampler2D shadowcolor0;
	uniform sampler2D shadowtex0;
	uniform sampler2D shadowtex1;

    #ifdef SHADOW_ENABLE_HWCOMP
        uniform sampler2DShadow shadow;
    #endif
	
	uniform vec3 shadowLightPosition;
	
	#if SHADOW_TYPE != 0
		uniform mat4 shadowProjection;
	#endif
#endif

#include "/lib/noise.glsl"

#ifdef SHADOW_ENABLED
	#if SHADOW_PCF_SAMPLES == 12
		#include "/lib/shadows/poisson_12.glsl"
	#elif SHADOW_PCF_SAMPLES == 24
		#include "/lib/shadows/poisson_24.glsl"
	#elif SHADOW_PCF_SAMPLES == 36
		#include "/lib/shadows/poisson_36.glsl"
	#endif
	
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

	#if SHADOW_TYPE == 3 && defined DEBUG_CASCADE_TINT && defined SHADOW_ENABLED
		color.rgb *= 1.0 - LOD_TINT_FACTOR * (1.0 - shadowTileColor);
	#endif
	
	ApplyFog(color);

	color.rgb = LinearToRGB(color.rgb);

	/* DRAWBUFFERS:0 */
	gl_FragData[0] = color;
}

#define RENDER_TEXTURED
#define RENDER_FRAG

#include "/lib/common.glsl"
#include "/lib/constants.glsl"

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 vPos;
in vec3 vNormal;
in float geoNoL;

#ifdef SHADOW_ENABLED
    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        in vec3 shadowPos[4];
        flat in int shadowTile;

        #ifndef IS_IRIS
            flat in vec2 shadowProjectionSize[4];
            flat in float cascadeSize[4];
        #endif
    #elif SHADOW_TYPE != SHADOW_TYPE_NONE
        in vec3 shadowPos;
    #endif
#endif

uniform sampler2D texture;
uniform sampler2D lightmap;

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

#ifdef SHADOW_ENABLED
    uniform sampler2D shadowcolor0;
    uniform sampler2D shadowtex0;
    uniform sampler2D shadowtex1;

    #ifdef SHADOW_ENABLE_HWCOMP
        #ifndef IS_OPTIFINE
            uniform sampler2DShadow shadowtex0HW;
        #else
            uniform sampler2DShadow shadow;
        #endif
    #endif
    
    uniform vec3 shadowLightPosition;

    #if SHADOW_TYPE != SHADOW_TYPE_NONE
        uniform mat4 shadowProjection;
    #endif
#endif

#include "/lib/noise.glsl"

#ifdef SHADOW_ENABLED
    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        #include "/lib/shadows/csm.glsl"
        #include "/lib/shadows/csm_render.glsl"
    #elif SHADOW_TYPE != SHADOW_TYPE_NONE
        #include "/lib/shadows/basic.glsl"
        #include "/lib/shadows/basic_render.glsl"
    #endif
#endif

#include "/lib/lighting.glsl"


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;

void main() {
    vec4 color = BasicLighting();

    ApplyFog(color);

    color.rgb = LinearToRGB(color.rgb);
    outColor0 = color;
}

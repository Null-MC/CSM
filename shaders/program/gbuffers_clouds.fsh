#define RENDER_CLOUDS
#define RENDER_GBUFFER
#define RENDER_FRAG

#include "/lib/common.glsl"
#include "/lib/constants.glsl"

in vec2 texcoord;
in vec4 glcolor;

#ifndef SHADOW_BLUR
    in vec3 localPos;
#endif

uniform sampler2D gtexture;

#if MC_VERSION >= 11700
    uniform float alphaTestRef;
#endif

#ifndef SHADOW_BLUR
    #ifdef IS_IRIS
        uniform sampler2D texLightMap;
    #else
        uniform sampler2D lightmap;
    #endif

    uniform vec3 upPosition;
    uniform vec3 skyColor;
    uniform float far;

    uniform vec3 fogColor;
    uniform float fogDensity;
    uniform float fogStart;
    uniform float fogEnd;
    uniform int fogShape;
    uniform int fogMode;

    #include "/lib/lighting.glsl"
#endif


/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 outColor0;
#ifdef SHADOW_BLUR
    layout(location = 1) out vec4 outColor1;
    layout(location = 2) out vec4 outColor2;
#endif

void main() {
    vec4 color = texture(gtexture, texcoord);

    if (color.a < alphaTestRef) {
        discard;
        return;
    }

    vec2 lmcoord = vec2(1.0/32.0, 31.0/32.0);

    #ifdef SHADOW_BLUR
        outColor0 = color;
        outColor1 = vec4(glcolor.rgb, 1.0);
        outColor2 = vec4(lmcoord, glcolor.a, 1.0);
    #else
        //color.rgb *= glcolor.rgb;
        //outColor0 = color;
        outColor0 = GetFinalLighting(color, glcolor.rgb, localPos, lmcoord, glcolor.a);
    #endif
}

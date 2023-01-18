#define RENDER_CLOUDS
#define RENDER_GBUFFER
#define RENDER_VERTEX

#include "/lib/common.glsl"
#include "/lib/constants.glsl"

out vec2 texcoord;
out vec4 glcolor;

#ifndef SHADOW_BLUR
    out vec3 localPos;

    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelViewInverse;
#endif


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;

    #ifndef SHADOW_BLUR
        vec3 viewPos = (gbufferProjectionInverse * gl_Position).xyz;
        localPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    #endif
}

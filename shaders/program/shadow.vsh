#define RENDER_SHADOW
#define RENDER_VERTEX

#include "/lib/common.glsl"
#include "/lib/constants.glsl"

in vec4 mc_Entity;
in vec3 vaPosition;
in vec3 at_midBlock;

out vec2 vTexcoord;
out vec4 vColor;

#if SHADOW_TYPE == 3
	flat out vec3 vOriginPos;
	flat out int vBlockId;
	flat out int vEntityId;
#endif

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform int renderStage;

#if MC_VERSION >= 11700 && !defined IS_IRIS
    uniform vec3 chunkOffset;
#else
    uniform mat4 gbufferModelViewInverse;
#endif

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
	uniform int entityId;
	uniform float near;
	uniform float far;

    #ifndef IS_IRIS
        // NOTE: We are using the previous gbuffer matrices cause the current ones don't work in shadow pass
        uniform mat4 gbufferPreviousModelView;
        uniform mat4 gbufferPreviousProjection;
    #else
        uniform mat4 gbufferModelView;
        uniform mat4 gbufferProjection;
    #endif
#endif

#ifdef ENABLE_WAVING
	#include "/lib/waving.glsl"
#endif


void main() {
	vTexcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	vColor = gl_Color;

	int blockId = int(mc_Entity.x + 0.5);

	#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        #if MC_VERSION >= 11700 && !defined IS_IRIS
            vOriginPos = floor(vaPosition + chunkOffset + at_midBlock / 64.0 + fract(cameraPosition));
        #else
            vOriginPos = floor(gl_Vertex.xyz + at_midBlock / 64.0 + fract(cameraPosition));
        #endif

    	vOriginPos = (gl_ModelViewMatrix * vec4(vOriginPos, 1.0)).xyz;

	    if (renderStage == MC_RENDER_STAGE_ENTITIES) {
			vEntityId = entityId;
	    }
	    else {
			vBlockId = blockId;
	    }
	#endif

	vec4 pos = gl_Vertex;

	#ifdef ENABLE_WAVING
		if (blockId >= 10001 && blockId <= 10004)
			pos.xyz += GetWavingOffset();
	#endif

	gl_Position = gl_ModelViewMatrix * pos;
}

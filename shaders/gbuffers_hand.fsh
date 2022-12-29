#version 120

#extension GL_ARB_gpu_shader5 : enable

#define WORLD_OVERWORLD
#define RENDER_HAND
#define RENDER_FRAG

#include "overworld.glsl"
#include "/lib/common.glsl"
#include "/program/gbuffers_hand.fsh"

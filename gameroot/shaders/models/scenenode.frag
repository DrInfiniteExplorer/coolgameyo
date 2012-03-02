#version 150 core

#extension GL_EXT_gpu_shader4 : enable
#extension GL_ARB_explicit_attrib_location : enable

out vec2 tex_texcoord;

layout(location = 0) out vec4 frag_color;
layout(location = 1) out vec4 light;
layout(location = 2) out vec4 depth;
void main() {
   frag_color = vec4(tex_texcoord.xy, 0.0, 0.0);
   light = vec4(1.0);
   depth = vec4(1.0);
}


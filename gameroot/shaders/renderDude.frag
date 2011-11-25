#version 150 core

#extension GL_EXT_gpu_shader4 : enable
#extension GL_ARB_explicit_attrib_location : enable

uniform vec3 color;

uniform sampler2DArray textureAtlas;

in float Depth;
layout(location = 0) out vec4 frag_color;
layout(location = 1) out float depth;

void main() {

   frag_color = vec4(color, 0.0);
   depth = Depth;
} 





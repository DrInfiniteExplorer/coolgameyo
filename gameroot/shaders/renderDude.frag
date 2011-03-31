#version 150 core

#extension GL_EXT_gpu_shader4 : enable

uniform vec3 color;

uniform sampler2DArray textureAtlas;

out vec4 frag_color;
void main() {

   frag_color = vec4(color, 0.0);
} 





#version 150 core

#extension GL_EXT_gpu_shader4 : enable

uniform sampler2DArray textureAtlas;

out vec4 frag_color;
void main() {

   frag_color = vec4(1.0, 0.0, 0.0, 0.0);
} 





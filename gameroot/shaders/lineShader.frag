#version 150 core

#extension GL_EXT_gpu_shader4 : enable

uniform vec3 color;
uniform float radius;

in vec3 viewPos;
out vec4 frag_color;
void main() {
   float dist = length(viewPos);
   float tmp = 1.0 - dist/radius;
   frag_color = vec4(tmp * color, 0.0);
} 





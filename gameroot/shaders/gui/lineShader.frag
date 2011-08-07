#version 150 core

uniform sampler2D tex;

in vec3 color;

vec4 frag_color;
void main() {
   frag_color = vec4(color, 1.0);
}


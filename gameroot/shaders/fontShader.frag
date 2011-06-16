#version 150 core

uniform sampler2D tex;

in vec2 tex_texcoord;

out vec4 frag_color;
void main() {
   vec4 color;
   color = texture2D(tex, tex_texcoord);
   frag_color = color;
}


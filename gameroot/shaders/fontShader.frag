#version 150 core

uniform sampler2D tex;
uniform vec3 color;

in vec2 tex_texcoord;

out vec4 frag_color;
void main() {
   vec4 texColor;
   texColor = texture2D(tex, tex_texcoord);
   frag_color = texColor * vec4(color, 1.0);
}


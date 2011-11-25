#version 150 core

#extension GL_ARB_separate_shader_objects : enable

uniform sampler2D texture;

in vec2 texcoord;

out vec4 frag_color;

void main() {
   vec4 texColor;
   texColor = texture2D(texture, texcoord);
   frag_color = texColor;
   //frag_color = vec4(0.0, 0.0, 0.0, texColor.r);
}


#version 150 core

#extension GL_EXT_gpu_shader4 : enable

uniform sampler2DArray atlas;

in vec3 tex_texcoord;
in float lightStrength;

out vec4 frag_color;
void main() {
   vec4 color = texture(atlas, tex_texcoord);
   frag_color = color * lightStrength;
}





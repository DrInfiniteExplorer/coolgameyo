#version 150 core

#extension GL_EXT_gpu_shader4 : enable

uniform sampler2D textureAtlas;
uniform int derp;

in vec2 tex_texcoord;

out vec4 frag_color;
void main() {

   if(derp == 0){
      frag_color = textureb(textureAtlas, tex_texcoord);
   }else{
      frag_color = vec4(1.0, 0.0, 0.0, 0.0);
   }
} 





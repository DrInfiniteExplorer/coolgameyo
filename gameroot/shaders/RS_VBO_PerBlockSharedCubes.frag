#version 150 core

#extension GL_EXT_gpu_shader4 : enable

uniform sampler2DArray textureAtlas;
uniform int derp;

in vec2 tex_texcoord;

out vec4 frag_color;
void main() {
   //frag_color = texture(textureAtlas, vec3(tex_texcoord, 0.0));
   if(derp == 0){
      frag_color = texture2DArray(textureAtlas, vec3(tex_texcoord, 0.0));
   }else{
      frag_color = vec4(1.0, 0.0, 0.0, 0.0);
   }
   //frag_color = vec4(tex_texcoord, 0.0, 0.0);
   //frag_color = vec4(0.5, 0.5, 0.5, 0.5);
} 





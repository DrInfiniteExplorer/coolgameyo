//#version 150 core

#extension GL_EXT_gpu_shader4 : enable

uniform sampler2DArray atlas;

in vec2 tex_texcoord;
flat in int texId;

out vec4 frag_color;
void main() {
   ivec3 index = tileIndexFromNumber(texId);
   //vec3 texcoord = vec3(index.xy * tileSize + mod(tex_texcoord, 1), index.z);
   vec3 texcoord = vec3(tex_texcoord.xy, 0.0);

   vec4 color = texture(atlas, texcoord);
   if(texId == 2){
      frag_color = vec4(1.0, 0.0, 0.0, 0.0);
   }else{
      frag_color = color;
   }
   
   frag_color = color;
} 





//#version 150 core

#extension GL_EXT_gpu_shader4 : enable

uniform sampler2DArray atlas;

in vec2 tex_texcoord;
flat in uint texId;

out vec4 frag_color;
void main() {
   uvec3 index = tileIndexFromNumber(texId);
   vec3 texcoord = vec3((index.xy + mod(tex_texcoord, 1)) * tileSize, index.z);

   //May want to use textureOffset as it can take the index.xy*tileSize as a separate parameter?
   //No, since we'd have to do two mults then.
   vec4 color = texture(atlas, texcoord);
   frag_color = color;
} 





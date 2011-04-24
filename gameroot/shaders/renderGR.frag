//#version 150 core

#extension GL_EXT_gpu_shader4 : enable

uniform sampler2DArray atlas;

in vec2 tex_texcoord;
flat in uint texId;

out vec4 frag_color;
void main() {
   uvec3 index = tileIndexFromNumber(texId);
   vec2 gradX = dFdx(tex_texcoord) * tileSize;
   vec2 gradY = dFdy(tex_texcoord) * tileSize;
   vec3 texcoord = vec3((index.xy + mod(tex_texcoord, 1.0)) * tileSize, index.z);

   //May want to use textureOffset as it can take the index.xy*tileSize as a separate parameter?
   //No, since we'd have to do two mults then.
   vec4 color = textureGrad(atlas, texcoord, gradX, gradY);

   frag_color = color;
}





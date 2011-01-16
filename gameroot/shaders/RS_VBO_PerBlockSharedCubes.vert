#version 150 core


const float pixelWidth = 1.0/1024.0;
const vec2 tileSize = vec2(16.0, 16.0) * pixelWidth;

uniform mat4 MVP; //Not really, just VP
uniform ivec3 blockPos; 

in vec3 in_vertex;
in vec2 in_texcoord;
const int tileTexIdx = 0;
const int tileDecIdx = 0;

out vec2 tex_texcoord;
   
void main(){
   tex_texcoord = tileSize*tileTexIdx + in_texcoord;
   gl_Position = MVP * vec4(in_vertex+blockPos, 1.0);
}




#version 150 core


const float pixelWidth = 1.0/1024.0;
const vec2 tileSize = vec2(16.0, 16.0) * pixelWidth;

uniform mat4 VP;
uniform ivec3 offset; 

in vec3 position;
in int type;

out vec2 tex_texcoord;
   
void main(){

   //tex_texcoord = tileSize*tileTexIdx + in_texcoord;

   gl_Position = VP * vec4(position+offset, 1.0);
}




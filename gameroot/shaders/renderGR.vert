#version 150 core

uniform mat4 VP;
uniform ivec3 offset; 

in vec3 position;
in vec3 texcoord;

smooth out vec3 tex_texcoord;
flat out uint texId;
   
void main(){
   tex_texcoord = texcoord;
   gl_Position = VP * vec4(position+vec3(offset), 1.0);
}




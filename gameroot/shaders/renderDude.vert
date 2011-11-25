#version 150 core

uniform mat4 VP;
uniform mat4 M; 

in vec3 position;
out float Depth;
   
void main(){

    vec4 pos = VP *M* vec4(position, 1.0);
   gl_Position = pos;
   Depth = pos.z;
}




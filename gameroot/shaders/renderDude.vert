#version 150 core

uniform mat4 VP;
uniform mat4 M; 

in vec3 position;

smooth out vec3 worldPosition;
   
void main(){

   vec4 pos = VP *M* vec4(position, 1.0);
   gl_Position = pos;

   worldPosition = position;

}




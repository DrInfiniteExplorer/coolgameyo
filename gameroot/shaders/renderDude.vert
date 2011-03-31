#version 150 core

uniform mat4 VP;
uniform mat4 M; 

in vec3 position;
   
void main(){


   gl_Position = VP *M* vec4(position, 1.0);
}




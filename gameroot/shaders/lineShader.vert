#version 150 core

uniform mat4 V;
uniform mat4 VP;

in vec3 position;

out vec3 viewPos;   
void main(){

   viewPos = (V * vec4(position, 1.0)).xyz;
   gl_Position = VP * vec4(position, 1.0);
}




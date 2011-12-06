#version 150 core

uniform mat4 V;
uniform mat4 VP;

in vec3 position;

out vec3 viewPos;   

smooth out vec3 worldPosition;

void main(){

   viewPos = (V * vec4(position, 1.0)).xyz;
   gl_Position = VP * vec4(position, 1.0);

   worldPosition = position;
}




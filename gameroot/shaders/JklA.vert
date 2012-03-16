#version 150 core

uniform mat4 VP;
uniform vec3 offset; 

in vec3 position;
in vec3 normal;
in vec3 color;

out vec3 interp_normal;
out vec3 interp_color;
   
void main(){
   vec4 pos = VP * vec4(position+offset, 1.0);
   gl_Position = pos;
   interp_normal = normal;
   interp_color = color;
}




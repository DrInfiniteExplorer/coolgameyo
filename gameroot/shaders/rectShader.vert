#version 150 core

in vec2 position;
in vec3 in_color;

smooth out vec3 color;

void main(){
   color = in_color;
   vec2 tmp = position*2+vec2(-1,-1); //Mult-add :)
   gl_Position = vec4(tmp, 0.0, 1.0);
}




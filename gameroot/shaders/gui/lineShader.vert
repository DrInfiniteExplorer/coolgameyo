#version 150 core

in vec2 position;
in vec3 in_color;

smooth out vec3 color;

void main(){
   vec2 tmp;
   color = in_color;
   tmp = position*2+vec2(-1,-1); //Mult-add :)
   //tmp = position;
   gl_Position = vec4(tmp, 0.0, 1.0);
}




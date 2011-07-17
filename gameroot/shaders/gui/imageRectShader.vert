#version 150 core

in vec2 position;
in vec2 texcoord;

smooth out vec2 texcoords;

void main(){
   vec2 tmp;
   texcoords = texcoord;
   tmp = position*2+vec2(-1,-1); //Mult-add :)
   //tmp = position;
   gl_Position = vec4(tmp, 0.0, 1.0);
}




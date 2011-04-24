#version 150 core

uniform vec2 offset;
uniform vec2 viewportInv;

in vec2 position;
in vec2 texcoord;

smooth out vec2 tex_texcoord;

void main(){
   tex_texcoord = texcoord;
   vec2 tmp = (position+vec2(offset))*viewportInv*2-vec2(1,1);
   gl_Position = vec4(tmp, 0.0, 1.0);
}




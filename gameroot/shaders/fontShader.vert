#version 150 core

uniform ivec2 offset;
uniform vec2 viewportInv;

in vec2 position;
in vec2 texcoord;

out vec2 tex_texcoord;

void main(){
   tex_texcoord = texcoord;
   vec2 asd = vec2(offset)*viewportInv;
   asd.y = 1-asd.y;
   vec2 tmp = (position*viewportInv + asd)*2-vec2(1,1);
   gl_Position = vec4(tmp, 0.0, 1.0);
}




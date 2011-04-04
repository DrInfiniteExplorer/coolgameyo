//#version 150 core

uniform mat4 VP;
uniform vec3 offset; 

in vec3 position;
in vec2 texcoord;
in int type;

out vec2 tex_texcoord;
flat out int texId;
   
void main(){
   tex_texcoord = texcoord;
   texId = type;
   gl_Position = VP * vec4(position+offset, 1.0);
}




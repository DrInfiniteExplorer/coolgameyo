//#version 150 core

uniform mat4 VP;
uniform ivec3 offset; 

in ivec3 position;
in vec2 texcoord;
in uint type;

out vec2 tex_texcoord;
flat out uint texId;
   
void main(){
   tex_texcoord = texcoord;
   texId = type;




   gl_Position = VP * vec4(position+offset, 1.0);
}




#version 150 core

uniform mat4 VP;
uniform ivec3 offset; 
uniform vec3 campos; 

in vec3 position;
in vec3 texcoord;
in float light;
in float sunLight;

out vec3 tex_texcoord;
out float lightStrength;
out float sunLightStrength;
out vec3 camdist;
   
void main(){
   tex_texcoord = texcoord;
   vec4 pos = VP * vec4(position+vec3(offset), 1.0);
   gl_Position = pos;
   //lightStrength = light;
   lightStrength = light;
   sunLightStrength = sunLight;
   camdist = campos- (position+vec3(offset));
}




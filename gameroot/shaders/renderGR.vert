#version 150 core

uniform mat4 VP;
uniform ivec3 offset; 

in vec3 position;
in vec3 texcoord;
in float light;
in float sunLight;

out vec3 tex_texcoord;
out float lightStrength;
out float sunLightStrength;
   
void main(){
   tex_texcoord = texcoord;
   gl_Position = VP * vec4(position+vec3(offset), 1.0);
   //lightStrength = light;
   lightStrength = light;
   sunLightStrength = sunLight;
}




#version 150 core

uniform mat4 VP;
uniform ivec3 offset; 

in vec3 position;
in vec3 texcoord;
in float light;
in float sunLight;
in float normal;

out vec3 tex_texcoord;
out float lightStrength;
out float sunLightStrength;

smooth out vec3 worldPosition;
flat out int worldNormal;
   
void main(){
   tex_texcoord = texcoord;
   vec4 pos = VP * vec4(position+vec3(offset), 1.0);
   gl_Position = pos;
   lightStrength = light;
   sunLightStrength = sunLight;

   worldPosition = position+vec3(offset);
   worldNormal = int(normal);
}




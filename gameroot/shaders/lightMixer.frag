#version 150 core

#extension GL_ARB_separate_shader_objects : enable

uniform sampler2D albedoTex;
uniform sampler2D minecraftLightTex;
uniform sampler2D raycastLightTex;
uniform int method;

in vec2 texcoord;

out vec4 frag_color;

void main() {
   vec4 albedo = texture2D(albedoTex, texcoord);
   vec4 minecraftLight = texture2D(minecraftLightTex, texcoord);
   vec4 raycastLight = texture2D(raycastLightTex, texcoord);
   vec4 color;
   if(method == 0) {
        color = albedo * (minecraftLight + raycastLight);
   } else if (method == 1) {
        color = albedo * minecraftLight;
   } else if (method == 2) {
        color = albedo * raycastLight;
   } else if (method == 3) {
        color = albedo;
   } else if (method == 4) {
        color = minecraftLight;
   } else if (method == 5) {
        color = raycastLight;
   }

   frag_color = color;
}


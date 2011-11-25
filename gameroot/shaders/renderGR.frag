#version 150 core

#extension GL_EXT_gpu_shader4 : enable
#extension GL_ARB_explicit_attrib_location : enable

uniform sampler2DArray atlas;
uniform vec3 SkyColor;

in vec3 tex_texcoord;
in float lightStrength;
in float sunLightStrength;
in vec3 camdist;

layout(location = 0) out vec4 frag_color;
layout(location = 1) out float depth;
void main() {
   vec4 color = texture(atlas, tex_texcoord);
   frag_color = vec4(color.rgb * max(vec3(lightStrength), SkyColor * sunLightStrength), 1.0);
   depth = length(camdist);
}





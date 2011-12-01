#version 150 core

#extension GL_EXT_gpu_shader4 : enable
#extension GL_ARB_explicit_attrib_location : enable

uniform sampler2DArray atlas;
uniform vec3 SkyColor;

in vec3 tex_texcoord;
in float lightStrength;
in float sunLightStrength;
smooth in vec3 worldPosition;
flat in int worldNormal;

layout(location = 0) out vec4 frag_color;
layout(location = 1) out vec4 light;
layout(location = 2) out vec4 depth;
void main() {
   frag_color = texture(atlas, tex_texcoord);
   light = vec4(max(vec3(lightStrength), SkyColor * sunLightStrength), 1.0);
   depth = vec4(worldPosition, float(worldNormal));
}





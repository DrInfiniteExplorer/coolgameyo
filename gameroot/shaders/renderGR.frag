#version 150 core

#extension GL_EXT_gpu_shader4 : enable
#extension GL_ARB_explicit_attrib_location : enable

uniform sampler2DArray atlas;
uniform vec3 SkyColor;
uniform float minZ;

in vec3 tex_texcoord;
in float lightStrength;
in float sunLightStrength;
smooth in vec3 worldPosition;
flat in int worldNormal;

layout(location = 0) out vec4 frag_color;
layout(location = 1) out vec4 light;
layout(location = 2) out vec4 depth;
void main() {
    vec4 color = texture(atlas, tex_texcoord); 
    if(worldPosition.z > minZ+2.01) {
        discard;
    }
	if(worldPosition.z < minZ-0.1) {
		float intensity = dot(color.xyz, vec3(0.2989, 0.5870, 0.1140));
		float fadeRange = 0.8;
		float distanceBelowGrid = -(worldPosition.z - minZ - 0.1);
		float t = clamp(distanceBelowGrid, 0.0, fadeRange) / fadeRange;
		color = mix(color, vec4(vec3(intensity), 1.0), t);
	}
   frag_color = color;
   light = vec4(max(vec3(lightStrength), SkyColor * sunLightStrength), 1.0);
   depth = vec4(worldPosition, float(worldNormal));
}





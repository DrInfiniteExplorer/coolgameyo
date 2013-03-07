#version 150 core

#extension GL_EXT_gpu_shader4 : enable
#extension GL_ARB_explicit_attrib_location : enable

uniform vec3 sunDir;

in vec3 interp_normal;
in vec3 interp_color;

layout(location = 0) out vec4 frag_color;
layout(location = 1) out vec4 light;
layout(location = 2) out vec4 depth;
void main() {
    vec3 up = sunDir; //vec3(0, 0, 1);
    float dt = clamp(
        dot(
            up, normalize(interp_normal)
            ),
        0.0, 1.0);
    frag_color = vec4(interp_color * dt, 1.0);

    //frag_color = vec4(mod(interp_normal.x, 10.0)/10.0);
    //frag_color = vec4(0.0);


   light = vec4(1.0);
   depth = vec4(10000.0);
}





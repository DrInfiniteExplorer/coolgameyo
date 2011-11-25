#version 150 core

in vec3 vertex;

out vec2 texcoord;

void main(){
    texcoord = vertex.xy * 0.5 + vec2(0.5, 0.5);
    gl_Position = vec4(vertex.xy, 0.0, 1.0);
}




#version 150 core

uniform sampler2D tex;

in vec3 color;

uniform float stripes;

out vec4 frag_color;
void main() {
   if(stripes != 0) {
        float tmp = dot(gl_FragCoord.xy, vec2(1.0, 1.0));
        if( mod(tmp, 2.0) < stripes) {
            discard;
        }
   }
   frag_color = vec4(color, 1.0);
}


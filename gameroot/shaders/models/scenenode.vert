#version 150 core

uniform mat4 VP;


in vec3 position;
in vec2 texcoord;
/*
in vec3 normal;
in uint bones;
in vec4 weights;
*/


in vec3 pos;
in uint texIdx;
in vec3 scale;
/*
in vec3 rot;
in uint animationIndex;
in uint frameIndex;
*/


out vec3 tex_texcoord;
   
void main(){
   tex_texcoord = vec3(texcoord, texIdx);

   vec3 Pos;
   //Animate vertex
    //derp
   //Rotate vertex w. instance quat
    //derp
   //Place vertex w. instance pos
   //Pos = Pos + vec4(pos, 0.0);
   //Pos = vec4(position, 1.0) - vec4(2.0, 2.0, 2.0, 0.0);
   //View it
   //gl_Position = VP * Pos;
   Pos = position.xyz + pos;
   gl_Position = VP * vec4(Pos*scale, 1.0);
}




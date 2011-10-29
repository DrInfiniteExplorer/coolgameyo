module light;

import util.util;

const enum MaxLightStrength = 16;

//A class, because we want it to reside on the heap, so that a light-creator can update the light
// without always going trough the world?
//Another method would be to use a 'global' id to identify it with, or just its vec3i-position?
class LightSource {
    vec3d position;
    ubyte strength; //0-16
    vec3d tint;
    //Eventually add other stuff as well?
}
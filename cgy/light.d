module light;

import pos;
import util.util;

immutable MaxLightStrength = 15;

//A class, because we want it to reside on the heap, so that a light-creator can update the light
// without always going trough the world?
//Another method would be to use a 'global' id to identify it with, or just its vec3i-position?
class LightSource {
    EntityPos position;
    ubyte strength; //0-15
    vec3d tint;
    //Eventually add other stuff as well?
}

module random.peturber;

import util.util;
import random.valuesource;

final class Peturber : ValueSource {
    ValueSource source;
    ValueSource petX;
    ValueSource petY;
    ValueSource petZ;
    vec3d power;
    
    this(ValueSource s, ValueSource pX = null, ValueSource pY = null, ValueSource pZ = null, vec3d p = vec3d(1,1,1)) {
        source = s;
        petX = pX;
        petY = pY;
        petZ = pZ;
        power = p;
    }
    
    override double getValue3(vec3d pos) {
        vec3d newPos = pos;
        if (petX !is null) {
            newPos.x += petX.getValue3(pos) * power.x;
        }
        if (petY !is null) {
            newPos.y += petY.getValue3(pos) * power.y;
        }
        if (petZ !is null) {
            newPos.z += petZ.getValue3(pos) * power.z;
        }
        return source.getValue3(newPos);
    }
    override double getValue2(vec2d pos) {
        vec2d newPos = pos;
        if (petX !is null) {
            newPos.x += petX.getValue2(pos) * power.x;
        }
        if (petY !is null) {
            newPos.y += petY.getValue2(pos) * power.y;
        }
        return source.getValue2(newPos);
    }
    override double getValue(double x) {
        if (petX !is null) {
            x += petX.getValue(x) * power.x;
        }
        return source.getValue(x);
    }    
}

module random.peturber;

import util.util;
import random.random;

class Peturber : ValueSource {
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
    
    double getValue(double x, double y, double z) {
        if (petX !is null) {
            x += petX.getValue(x, y, z) * power.X;
        }
        if (petY !is null) {
            y += petY.getValue(x, y, z) * power.Y;
        }
        if (petZ !is null) {
            z += petZ.getValue(x, y, z) * power.Z;
        }
        return source.getValue(x, y, z);
    }
    double getValue(double x, double y) {
        if (petX !is null) {
            x += petX.getValue(x, y) * power.X;
        }
        if (petY !is null) {
            y += petY.getValue(x, y) * power.Y;
        }
        return source.getValue(x, y);
    }
    double getValue(double x) {
        if (petX !is null) {
            x += petX.getValue(x) * power.X;
        }
        return source.getValue(x);
    }    
}

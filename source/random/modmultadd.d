module random.modmultadd;

import util.util;
import random.random;

class ModMultAdd(double mult, double offset) : ValueSource {
    ValueSource source;
    this(ValueSource s) {
        source = s;
    }
    
    double getValue3(vec3d pos) {
        auto v = source.getValue(x, y, z) * mult + offset;
        return v;
    }
    
    double getValue2(vec2d pos) {
        auto v = source.getValue(x, y) * mult + offset;
        return v;
    }
    double getValue(double x) {
        auto v = source.getValue(x) * mult + offset;
        return v;
    }
}

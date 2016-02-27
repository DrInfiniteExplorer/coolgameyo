module random.randsource;

import std.random;

import cgy.util.util;
import random.valuesource;

final class RandSourceUniform : ValueSource {
    Random gen;
    double min, max;
    this(uint seed, double _min = -1.0, double _max = 1.0) {
        gen.seed(seed);
        min = _min;
        max = _max;
    }
    override double getValue3(vec3d pos) {
        return getValue(pos.x);
    }
    override double getValue2(vec2d pos) {
        return getValue(pos.x);
    }
    override double getValue(double x) {
        return uniform(min, max, gen);
    }
    Type get(Type)(Type miin, Type maax) {
        auto v = uniform(miin, maax, gen);
        return v;
    }
}

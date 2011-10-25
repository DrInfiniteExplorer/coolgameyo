module random.randsource;

import std.random;

import util.util;
import random.random;

class RandSourceUniform : ValueSource {
    Random gen;
    double min, max;
    this(uint seed, double _min = -1.0, double _max = 1.0) {
        gen.seed(seed);
        min = _min;
        max = _max;
    }
    double getValue(double x, double y, double z) {
        return getValue(x);
    }
    double getValue(double x, double y) {
        return getValue(x);
    }
    double getValue(double x) {
        return uniform(min, max, gen);
    }
    Type get(Type)(Type miin, Type maax) {
        auto v = uniform(miin, maax, gen);
        return v;
    }
}

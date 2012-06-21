module random.map;

import util.util;

import random.valuesource;

final class Map : ValueSource { //Like the higher order function map, this maps stuff from stuff to stuff.
    ValueSource source;
    double delegate(double) f;
    this(ValueSource s, double delegate(double) _f) {
        source = s;
        f = _f;
    }

    override double getValue(double x, double y, double z) {
        return f(source.getValue(x, y, z));
    }
    override double getValue(double x, double y) {
        return f(source.getValue(x, y));
    }
    override double getValue(double x) {
        return f(source.getValue(x));
    }    
}


final class Map2D : ValueSource2D { //Like the higher order function map, this maps stuff from stuff to stuff.
    ValueSource2D source;
    vec2d delegate(vec2d) f;
    this(ValueSource2D s, vec2d delegate(vec2d) _f) {
        source = s;
        f = _f;
    }

    override vec2d getValue(double x, double y, double z) {
        return f(source.getValue(x, y, z));
    }
    override vec2d getValue(double x, double y) {
        return f(source.getValue(x, y));
    }
    override vec2d getValue(double x) {
        return f(source.getValue(x));
    }    
}



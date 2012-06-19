module random.map;

import random.random;

class Map(alias f) : ValueSource { //Like the higher order function map, this maps stuff from stuff to stuff.
    ValueSource source;
    this(ValueSource s) {
        source = s;
    }

    double getValue(double x, double y, double z) {
        return f(source.getValue(x, y, z));
    }
    double getValue(double x, double y) {
        return f(source.getValue(x, y));
    }
    double getValue(double x) {
        return f(source.getValue(x));
    }    
}

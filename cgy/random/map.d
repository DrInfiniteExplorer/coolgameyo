module random.map;



import random.random;

final class Map : ValueSource { //Like the higher order function map, this maps stuff from stuff to stuff.
    ValueSource source;
    double delegate(double) f;
    this(ValueSource s, double delegate(double) _f) {
        source = s;
        f = _f;
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

module random.xinterpolate;

import std.conv;
import std.math;

import util.util;
import random.random;

double XInterpolate(alias Lerp)(ValueSource source, double x, double y, double z) {
    //TODO: Do not assume that the source is a lattice with grid of size 1,1
    // Ie. dX dY may span [0, 1] over a range that is 4 long instead of current length 1.
    int loX = to!int(floor(x));
    int loY = to!int(floor(y));
    int loZ = to!int(floor(z));
    float dX = x - to!float(loX);
    float dY = y - to!float(loY);
    float dZ = z - to!float(loZ);
    double v000 = source.getValue(loX  , loY  , loZ  );
    double v100 = source.getValue(loX+1, loY  , loZ  );
    double v010 = source.getValue(loX  , loY+1, loZ  );
    double v110 = source.getValue(loX+1, loY+1, loZ  );
    double v001 = source.getValue(loX  , loY  , loZ+1);
    double v101 = source.getValue(loX+1, loY  , loZ+1);
    double v011 = source.getValue(loX  , loY+1, loZ+1);
    double v111 = source.getValue(loX+1, loY+1, loZ+1);
    auto v00 = Lerp(v000, v001, dZ);
    auto v01 = Lerp(v010, v011, dZ);
    auto v11 = Lerp(v110, v111, dZ);
    auto v10 = Lerp(v100, v101, dZ);
    auto v0 = Lerp(v00, v01, dY);
    auto v1 = Lerp(v10, v11, dY);
    return Lerp(v0, v1, dX);
}

double XInterpolate(alias Lerp)(ValueSource source, double x, double y) {
    //TODO: Do not assume that the source is a lattice with grid of size 1,1
    // Ie. dX dY may span [0, 1] over a range that is 4 long instead of current length 1.
    int loX = to!int(floor(x));
    int loY = to!int(floor(y));
    float dX = x - to!float(loX);
    float dY = y - to!float(loY);
    auto tx1 = Lerp(source.getValue(loX, loY),   source.getValue(loX+1, loY), dX);
    auto tx2 = Lerp(source.getValue(loX, loY+1), source.getValue(loX+1, loY+1), dX);
    return Lerp(tx1, tx2, dY);
}

double XInterpolate(alias Lerp)(ValueSource source, double x) {
    //TODO: Do not assume that the source is a lattice with grid of size 1,1
    // Ie. dX dY may span [0, 1] over a range that is 4 long instead of current length 1.
    int loX = to!int(floor(x));
    float dX = x - to!float(loX);
    auto tx1 = Lerp(source.getValue(loX),   source.getValue(loX+1), dX);
    return tx1;
}

class XInterpolation(alias Lerp) : ValueSource{
    ValueSource source;
    this(ValueSource _source) {
        source = _source;
    }
    double getValue(double x, double y, double z) {
        return XInterpolate!Lerp(source, x,y,z);
    }
    double getValue(double x, double y) {
        return XInterpolate!Lerp(source, x,y);
    }
    double getValue(double x) {
        return XInterpolate!Lerp(source, x);
    }
}

alias XInterpolation!CosInter CosInterpolation;
alias XInterpolation!SmoothInter SmoothInterpolation;


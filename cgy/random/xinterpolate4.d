module random.xinterpolate4;

import std.conv;
import std.exception;
import std.math;

import util.util;
import random.random;
import random.valuesource;


double XInterpolate4(alias Mixer)(ValueSource source, double x, double y, double z) {
    //TODO: Do not assume that the source is a lattice with grid of size 1,1
    // Ie. dX dY may span [0, 1] over a range that is 4 long instead of current length 1.
    /*
    int loX = to!int(floor(x));
    int loY = to!int(floor(y));
    int loZ = to!int(floor(z));
    float dX = x - to!float(loX);
    float dY = y - to!float(loY);
    float dZ = z - to!float(loZ);
    double v000 = source.getValue(loX-1, loY-1, loZ-1);
    double v001 = source.getValue(loX-1, loY-1, loZ+0);
    double v002 = source.getValue(loX-1, loY-1, loZ+1);
    double v003 = source.getValue(loX-1, loY-1, loZ+2);
    double v010 = source.getValue(loX-1, loY+0, loZ-1);
    double v011 = source.getValue(loX-1, loY+0, loZ+0);
    double v012 = source.getValue(loX-1, loY+0, loZ+1);
    double v013 = source.getValue(loX-1, loY+0, loZ+2);
    double v020 = source.getValue(loX-1, loY+1, loZ-1);
    double v021 = source.getValue(loX-1, loY+1, loZ+0);
    double v022 = source.getValue(loX-1, loY+1, loZ+1);
    double v023 = source.getValue(loX-1, loY+1, loZ+2);
    double v030 = source.getValue(loX-1, loY+2, loZ-1);
    double v031 = source.getValue(loX-1, loY+2, loZ+0);
    double v032 = source.getValue(loX-1, loY+2, loZ+1);
    double v033 = source.getValue(loX-1, loY+2, loZ+2);
    double v100 = source.getValue(loX-1, loY-1, loZ-1);
    double v101 = source.getValue(loX-1, loY-1, loZ+0);
    double v102 = source.getValue(loX-1, loY-1, loZ+1);
    double v103 = source.getValue(loX-1, loY-1, loZ+2);
    double v110 = source.getValue(loX-1, loY+0, loZ-1);
    double v111 = source.getValue(loX-1, loY+0, loZ+0);
    double v112 = source.getValue(loX-1, loY+0, loZ+1);
    double v113 = source.getValue(loX-1, loY+0, loZ+2);
    double v120 = source.getValue(loX-1, loY+1, loZ-1);
    double v121 = source.getValue(loX-1, loY+1, loZ+0);
    double v122 = source.getValue(loX-1, loY+1, loZ+1);
    double v123 = source.getValue(loX-1, loY+1, loZ+2);
    double v130 = source.getValue(loX-1, loY+2, loZ-1);
    double v131 = source.getValue(loX-1, loY+2, loZ+0);
    double v132 = source.getValue(loX-1, loY+2, loZ+1);
    double v133 = source.getValue(loX-1, loY+2, loZ+2);
    double v200 = source.getValue(loX-1, loY-1, loZ-1);
    double v201 = source.getValue(loX-1, loY-1, loZ+0);
    double v202 = source.getValue(loX-1, loY-1, loZ+1);
    double v203 = source.getValue(loX-1, loY-1, loZ+2);
    double v210 = source.getValue(loX-1, loY+0, loZ-1);
    double v211 = source.getValue(loX-1, loY+0, loZ+0);
    double v212 = source.getValue(loX-1, loY+0, loZ+1);
    double v213 = source.getValue(loX-1, loY+0, loZ+2);
    double v220 = source.getValue(loX-1, loY+1, loZ-1);
    double v221 = source.getValue(loX-1, loY+1, loZ+0);
    double v222 = source.getValue(loX-1, loY+1, loZ+1);
    double v223 = source.getValue(loX-1, loY+1, loZ+2);
    double v230 = source.getValue(loX-1, loY+2, loZ-1);
    double v231 = source.getValue(loX-1, loY+2, loZ+0);
    double v232 = source.getValue(loX-1, loY+2, loZ+1);
    double v233 = source.getValue(loX-1, loY+2, loZ+2);
    double v300 = source.getValue(loX-1, loY-1, loZ-1);
    double v301 = source.getValue(loX-1, loY-1, loZ+0);
    double v302 = source.getValue(loX-1, loY-1, loZ+1);
    double v303 = source.getValue(loX-1, loY-1, loZ+2);
    double v310 = source.getValue(loX-1, loY+0, loZ-1);
    double v311 = source.getValue(loX-1, loY+0, loZ+0);
    double v312 = source.getValue(loX-1, loY+0, loZ+1);
    double v313 = source.getValue(loX-1, loY+0, loZ+2);
    double v320 = source.getValue(loX-1, loY+1, loZ-1);
    double v321 = source.getValue(loX-1, loY+1, loZ+0);
    double v322 = source.getValue(loX-1, loY+1, loZ+1);
    double v323 = source.getValue(loX-1, loY+1, loZ+2);
    double v330 = source.getValue(loX-1, loY+2, loZ-1);
    double v331 = source.getValue(loX-1, loY+2, loZ+0);
    double v332 = source.getValue(loX-1, loY+2, loZ+1);
    double v333 = source.getValue(loX-1, loY+2, loZ+2);
    auto v00 = Mixer(v000, v001, dZ);
    auto v01 = Mixer(v010, v011, dZ);
    auto v11 = Mixer(v110, v111, dZ);
    auto v10 = Mixer(v100, v101, dZ);
    auto v0 = Mixer(v00, v01, dY);
    auto v1 = Mixer(v10, v11, dY);
    return Mixer(v0, v1, dX);
    */
    enforce(false, "Hurr..... lots of controil points to get!!!");
    return typeof(return).init;
}

double XInterpolate4(alias Mixer)(ValueSource source, double x, double y) {
    //TODO: Do not assume that the source is a lattice with grid of size 1,1
    // Ie. dX dY may span [0, 1] over a range that is 4 long instead of current length 1.
    int loX = to!int(floor(x));
    int loY = to!int(floor(y));
    float dX = x - to!float(loX);
    float dY = y - to!float(loY);
    auto v00 = source.getValue(loX-1, loY-1);
    auto v01 = source.getValue(loX-1, loY+0);
    auto v02 = source.getValue(loX-1, loY+1);
    auto v03 = source.getValue(loX-1, loY+2);
    auto v10 = source.getValue(loX, loY-1);
    auto v11 = source.getValue(loX, loY+0);
    auto v12 = source.getValue(loX, loY+1);
    auto v13 = source.getValue(loX, loY+2);
    auto v20 = source.getValue(loX+1, loY-1);
    auto v21 = source.getValue(loX+1, loY+0);
    auto v22 = source.getValue(loX+1, loY+1);
    auto v23 = source.getValue(loX+1, loY+2);
    auto v30 = source.getValue(loX+2, loY-1);
    auto v31 = source.getValue(loX+2, loY+0);
    auto v32 = source.getValue(loX+2, loY+1);
    auto v33 = source.getValue(loX+2, loY+2);
    auto v0 = Mixer(v00, v01, v02, v03, dY);
    auto v1 = Mixer(v10, v11, v12, v13, dY);
    auto v2 = Mixer(v20, v21, v22, v23, dY);
    auto v3 = Mixer(v30, v31, v32, v33, dY);
    return Mixer(v0, v1, v2, v3, dX);
}

double XInterpolate4(alias Mixer)(ValueSource source, double x) {
    //TODO: Do not assume that the source is a lattice with grid of size 1,1
    // Ie. dX dY may span [0, 1] over a range that is 4 long instead of current length 1.
    int loX = to!int(floor(x));
    float dX = x - to!float(loX);
    auto v1 = source.getValue(loX-1);
    auto v2 = source.getValue(loX+0);
    auto v3 = source.getValue(loX+1);
    auto v4 = source.getValue(loX+2);
    auto tx1 = Mixer(v1, v2, v3, v4, dX);
    return tx1;
}

final class XInterpolation4(alias Mixer) : ValueSource{
    ValueSource source;
    this(ValueSource _source) {
        source = _source;
    }
    override double getValue(double x, double y, double z) {
        return XInterpolate4!Mixer(source, x,y,z);
    }
    override double getValue(double x, double y) {
        return XInterpolate4!Mixer(source, x,y);
    }
    override double getValue(double x) {
        return XInterpolate4!Mixer(source, x);
    }
}

alias XInterpolation4!CubicInter CubicInterpolation;

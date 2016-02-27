module random.xinterpolate;

import std.conv;
import std.math;

import cgy.math.math : fastFloor;
import cgy.util.traits;
import cgy.util.util;
import random.random;
import random.valuesource;

auto XInterpolate3(alias Lerp, alias get)(vec3d pos) {
    //TODO: Do not assume that the source is a lattice with grid of size 1,1
    // Ie. dX dY may span [0, 1] over a range that is 4 long instead of current length 1.
    int loX = fastFloor(pos.x);
    int loY = fastFloor(pos.y);
    int loZ = fastFloor(pos.z);
    float dX = pos.x - cast(float)loX;
    float dY = pos.y - cast(float)loY;
    float dZ = pos.z - cast(float)loZ;
    double v000 = get(vec3d(loX  , loY  , loZ  ));
    double v100 = get(vec3d(loX+1, loY  , loZ  ));
    double v010 = get(vec3d(loX  , loY+1, loZ  ));
    double v110 = get(vec3d(loX+1, loY+1, loZ  ));
    double v001 = get(vec3d(loX  , loY  , loZ+1));
    double v101 = get(vec3d(loX+1, loY  , loZ+1));
    double v011 = get(vec3d(loX  , loY+1, loZ+1));
    double v111 = get(vec3d(loX+1, loY+1, loZ+1));
    auto v00 = Lerp(v000, v001, dZ);
    auto v01 = Lerp(v010, v011, dZ);
    auto v11 = Lerp(v110, v111, dZ);
    auto v10 = Lerp(v100, v101, dZ);
    auto v0 = Lerp(v00, v01, dY);
    auto v1 = Lerp(v10, v11, dY);
    return Lerp(v0, v1, dX);
}

auto XInterpolate2(alias Lerp, alias _get, T)(T pos) {
    //TODO: Do not assume that the source is a lattice with grid of size 1,1
    // Ie. dX dY may span [0, 1] over a range that is 4 long instead of current length 1.

    int loX = fastFloor(pos.x);
    int loY = fastFloor(pos.y);
    float dX = pos.x - cast(float)loX;
    float dY = pos.y - cast(float)loY;

    alias tryCall!(_get, int, int) get;

    auto v00 = get(loX, loY);
    auto v10 = get(loX+1, loY);
    auto v01 = get(loX, loY+1);
    auto v11 = get(loX+1, loY+1);

    auto tx1 = Lerp(v00, v10, dX);
    auto tx2 = Lerp(v01, v11, dX);
    return Lerp(tx1, tx2, dY);
}

auto XInterpolate(alias Lerp, Source)(Source source, double x) {
    //TODO: Do not assume that the source is a lattice with grid of size 1,1
    // Ie. dX dY may span [0, 1] over a range that is 4 long instead of current length 1.
    int loX = to!int(floor(x));
    float dX = x - to!float(loX);
    auto tx1 = Lerp(source.getValue(loX),   source.getValue(loX+1), dX);
    return tx1;
}

final class XInterpolation(alias Lerp) : ValueSource {
    ValueSource source;
    this(ValueSource _source) {
        source = _source;
    }
    override double getValue3(vec3d pos) {
        auto get = &source.getValue3;
        return XInterpolate3!(Lerp, get)(pos);
    }
    override double getValue2(vec2d pos) {
        auto get = &source.getValue2;
        return XInterpolate2!(Lerp, get)(pos);
    }
    override double getValue(double x) {
        return XInterpolate!(Lerp, ValueSource)(source, x);
    }
}

alias XInterpolation!CosInter CosInterpolation;
alias XInterpolation!SmoothInter SmoothInterpolation;


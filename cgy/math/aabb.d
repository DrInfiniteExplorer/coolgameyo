module math.aabb;

import std.algorithm;

import math.vector;

alias aabb2!int aabb2i;

struct aabb2(T) {
    alias vector2!T TVec;

    T xMin = void;
    T xMax = void;
    T yMin = void;
    T yMax = void;

    this(TVec min, TVec max) {
        this(min.x, max.x, min.y, max.y);
    }
    this(T _xMin, T _xMax, T _yMin, T _yMax) {
        xMin = _xMin;
        xMax = _xMax;
        yMin = _yMin;
        yMax = _yMax;
    }

    void reset(TVec t) {
        reset(t.x, t.y);
    }
    void reset(T x, T y) {
        xMin = x;
        xMax = x;
        yMin = y;
        yMax = y;
    }

    void addInternal(TVec t) {
        addInternal(t.x, t.y);
    }
    void addInternal(T x, T y) {
        xMin = std.algorithm.min(xMin, x);
        xMax = std.algorithm.max(xMax, x);
        yMin = std.algorithm.min(yMin, y);
        yMax = std.algorithm.max(yMax, y);
    }

    TVec min() const @property {
        return TVec(xMin, yMin);
    }
    TVec max() const @property {
        return TVec(xMax, yMax);
    }

    //Inclusive
    bool isInside(TVec t) const {
        return isInside(t.x, t.y);
    }
    bool isInside(T x, T y) const {
        return x >= xMin
            && x <=  xMax
            && y >= yMin
            && y <=  yMax;
    }




}

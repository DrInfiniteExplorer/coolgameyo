module cgy.math.aabb;

import std.algorithm;

import cgy.math.vector;

alias aabb2!int aabb2i;

alias aabb3!int aabb3i;
alias aabb3!float aabb3f;
alias aabb3!double aabb3d;

struct aabb3(T) {
    alias typeof(this) This;
    alias vector3!T TVec;

    T xMin = void;
    T xMax = void;
    T yMin = void;
    T yMax = void;
    T zMin = void;
    T zMax = void;

    this(TVec min, TVec max) {
        this(min.x, max.x, min.y, max.y, min.z, max.z);
    }
    this(T _xMin, T _xMax, T _yMin, T _yMax, T _zMin, T _zMax) {
        xMin = _xMin;
        xMax = _xMax;
        yMin = _yMin;
        yMax = _yMax;
        zMin = _zMin;
        zMax = _zMax;
    }

    void reset(TVec t) {
        reset(t.x, t.y, t.z);
    }
    void reset(T x, T y, T z) {
        xMin = x;
        xMax = x;
        yMin = y;
        yMax = y;
        zMin = z;
        zMax = z;
    }

    void addInternal(TVec t) {
        addInternal(t.x, t.y, t.z);
    }
    void addInternal(T x, T y, T z) {
        xMin = std.algorithm.min(xMin, x);
        xMax = std.algorithm.max(xMax, x);
        yMin = std.algorithm.min(yMin, y);
        yMax = std.algorithm.max(yMax, y);
        zMin = std.algorithm.min(zMin, z);
        zMax = std.algorithm.max(zMax, z);
    }

    void scale(TVec v) {
        scale(v.x, v.y, v.z);
    }
    void scale(T s) {
        scale(s, s, s);
    }
    void scale(T x, T y, T z) {
        auto sizeX = (xMax - xMin) * x / 2;
        auto sizeY = (yMax - yMin) * y / 2;
        auto sizeZ = (zMax - zMin) * z / 2;
        auto centerX = xMin / 2 + xMax / 2;
        auto centerY = yMin / 2 + yMax / 2;
        auto centerZ = zMin / 2 + zMax / 2;
        xMin = centerX - sizeX;
        yMin = centerY - sizeY;
        zMin = centerZ - sizeZ;
        xMax = centerX + sizeX;
        yMax = centerY + sizeY;
        zMax = centerZ + sizeZ;

    }
    void translate(TVec v) {
        translate(v.x, v.y, v.z);
    }
    void translate(T x, T y, T z) {
        xMin += x;
        xMax += x;
        yMin += y;
        yMax += y;
        zMin += z;
        zMax += z;
    }

    This move(TVec v) {
        return move(v.x, v.y, v.z);
    }
    This move(T x, T y, T z) {
        This that = this;
        that.move(x, y, z);
        return that;
    }


    TVec min() const @property {
        return TVec(xMin, yMin, zMin);
    }
    TVec max() const @property {
        return TVec(xMax, yMax, zMin);
    }
    TVec center() const @property {
        return TVec(xMin / 2 + xMax / 2,
                    yMin / 2 + yMax / 2,
                    zMin / 2 + zMax / 2);
    }

    //Inclusive
    bool isInside(TVec t) const {
        return isInside(t.x, t.y, t.z);
    }
    bool isInside(T x, T y, T z) const {
        return x >= xMin
            && x <=  xMax
            && y >= yMin
            && y <=  yMax
            && z >= zMin
            && z <=  zMax;
    }

    // Graphics
    TVec[8] getCorners() {
        TVec[8] ret = void;
        ret[0].set(xMin, yMin, zMin);
        ret[1].set(xMin, yMin, zMax);
        ret[2].set(xMin, yMax, zMin);
        ret[3].set(xMin, yMax, zMax);
        ret[4].set(xMin, yMin, zMin);
        ret[5].set(xMin, yMin, zMax);
        ret[6].set(xMax, yMax, zMin);
        ret[7].set(xMax, yMax, zMax);
        return ret;
    }
    TVec[24] getQuads() {
        TVec[24] ret = void;
        ret[0].set(xMin, yMin, zMin);
        ret[1].set(xMax, yMin, zMin);
        ret[2].set(xMax, yMin, zMax);
        ret[3].set(xMin, yMin, zMax);

        ret[4].set(xMin, yMax, zMin);
        ret[5].set(xMin, yMin, zMin);
        ret[6].set(xMin, yMin, zMax);
        ret[7].set(xMin, yMax, zMax);

        ret[8].set(xMax, yMax, zMin);
        ret[9].set(xMin, yMax, zMin);
        ret[10].set(xMin, yMax, zMax);
        ret[11].set(xMax, yMax, zMax);

        ret[12].set(xMax, yMin, zMin);
        ret[13].set(xMax, yMax, zMin);
        ret[14].set(xMax, yMax, zMax);
        ret[15].set(xMax, yMin, zMax);

        ret[16].set(xMin, yMin, zMax);
        ret[17].set(xMax, yMin, zMax);
        ret[18].set(xMax, yMax, zMax);
        ret[19].set(xMin, yMax, zMax);

        ret[20].set(xMin, yMax, zMin);
        ret[21].set(xMax, yMax, zMin);
        ret[22].set(xMax, yMin, zMin);
        ret[23].set(xMin, yMin, zMin);

        return ret;
    }

}


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

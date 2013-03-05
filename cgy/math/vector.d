module math.vector;

import std.traits : isFloatingPoint;
import std.math : atan2, sqrt, sin, cos;

import math.math;
import util.math : fastFloor;
import util.util : BREAKPOINT;

alias vector3 vec3;
alias vec3!double vec3d;
alias vec3!float vec3f;
alias vec3!int vec3i;
alias vec3!short vec3s;
alias vec3!ubyte vec3ub;


alias vector2 vec2;
alias vec2!double vec2d;
alias vec2!float vec2f;
alias vec2!int vec2i;

struct vector3(T) {
    T x = void;
    T y = void;
    T z = void;

    alias vector3!T vec;
    this(T _x) {
        x = y = z = _x;
    }
    this(T _x, T _y, T _z) {
        x = _x;
        y = _y;
        z = _z;
    }

    void set(T _x, T _y, T _z) {
        x = _x;
        y = _y;
        z = _z;
    }

    vec3!int fastFloor() const {
        static if(isFloatingPoint!T) {
            return vec3!int(
                            .fastFloor(x),
                            .fastFloor(y),
                            .fastFloor(z)
                            );
        } else {
            return convert!int;
        }
    }

    vec2!T v2() const {
        return vec2!T(x, y);
    }

    void toColor(ref ubyte r, ref ubyte g, ref ubyte b) {
        r = cast(ubyte)x;
        g= cast(ubyte)y;
        b = cast(ubyte)z;
    }
    ubyte[4] toColorUByte(ubyte alpha = 255) {
        ubyte[4] ret;
        ret[0] = cast(ubyte)x;
        ret[1]= cast(ubyte)y;
        ret[2] = cast(ubyte)z;
        ret[3] = alpha;
        return ret;
    }
    uint toColorUInt(ubyte alpha = 255) {
        ubyte[4] clr = toColorUByte(alpha);
        return *cast(uint*)clr.ptr;
    }
    void fromColor(uint clr) {
        ubyte[4] clr = *cast(ubyte[4]*)&clr;
        x = cast(T)clr[0];
        y = cast(T)clr[1];
        z = cast(T)clr[2];
    } 

    vec opBinary(string op, O)(const O o) const {
        vec ret = void;
        static if( is( O : vec)) {
            ret.x = cast(T) mixin("x " ~ op ~ " o.x");
            ret.y = cast(T) mixin("y " ~ op ~ " o.y");
            ret.z = cast(T) mixin("z " ~ op ~ " o.z");
        } else {
            ret.x = cast(T) mixin("x " ~ op ~ " cast(T) o");
            ret.y = cast(T) mixin("y " ~ op ~ " cast(T) o");
            ret.z = cast(T) mixin("z " ~ op ~ " cast(T) o");
        }
        return ret;
    }
    
    auto opBinaryRight(string op, O)(O o) const if(! is(O : vec)) {
        return opBinary!op(o);
    }
    
    void opOpAssign(string op, O)(const O o) {
        static if( is( O : vec)) {
            x = cast(T) mixin("x " ~ op ~ " o.x");
            y = cast(T) mixin("y " ~ op ~ " o.y");
            z = cast(T) mixin("z " ~ op ~ " o.z");
        } else {
            x = cast(T) mixin("x " ~ op ~ " o");
            y = cast(T) mixin("y " ~ op ~ " o");
            z = cast(T) mixin("z " ~ op ~ " o");
        }
    }
    vec opUnary(string s)() if (s == "-") {
        vec ret = void;
        ret.set(-x, -y, -z);
        return ret;
    }

    auto convert(O)() const {
        return vec3!O( cast(O)x, cast(O)y, cast(O)z);
    }

    ref T opIndex(size_t idx) {
        switch(idx) {
            case 0: return x;
            case 1: return y;
            case 2: return z;
            default:
        }
        BREAKPOINT;
        assert(0);
    }

    //Rationale for this: according to http://dlang.org/struct.html a temporary object is copied to
    // in every assignment, which is not necessary for vectors.
    /*
    void opAssign(const vec other) {
        //TODO: use standard blitting?
        x = other.x;
        y = other.y;
        z = other.z;
        vec* ptr = &this; // WHY IS THIS NEEDED? SHOULDN'T this BE OF TYPE vec* ALREADY??
        //pragma(msg, typeof(this));  -->  vec
        //pragma(msg, typeof(&this)); -->  vec*
        //return ptr;
    }
    */

    int opCmp(const vec other) const
    {
        T x = cast(T)(x - other.x);
        T y = cast(T)(y - other.y);
        T z = cast(T)(z - other.z);
        if(!x && !y && !z){ return 0;}
        if(x>0) {
            return 1;
        }
        if(x==0) {
            if(y>0) {
                return 1;
            }
            if(y==0) {
                if(z>0) {
                    return 1;
                }
            }
        }
        return -1;
    }

    bool equals(const vec o, const T tolerance = cast(T)0.000001f) const
    {
        import stolen.math : equals;
        return equals(x, o.x, tolerance) &&
            equals(y, o.y, tolerance) &&
            equals(z, o.z, tolerance);
    }

    T dotProduct(const vec o) const {
        return cast(T) (x * o.x + y * o.y + z * o.z);
        //return (this*o).sum;
    }

    vec crossProduct(const vec o) const {
        return vec( cast(T)( y * o.z - z * o.y) ,
                    cast(T)( z * o.x - x * o.z) ,
                    cast(T)( x * o.y - y * o.x));
    }

    T getLength() const {
        return cast(T)sqrt(cast(real)x^^2 + y^^2 + z^^2);
    }
    T getLengthSQ() const {
        return cast(T)(x^^2 + y^^2 + z^^2);
    }
    void setLength(T length) {
        immutable constant = cast(T)(length / getLength());
        x *= constant;
        y *= constant;
        z *= constant;
    }

    vec normalize() {
        setLength(1);
        return this;
    }

    T getDistance(const vec o) const {
        return cast(T)sqrt(cast(real) (x-o.x)^^2 + (y - o.y)^^2 + (z-o.z)^^2);
        //return sqrt(((this-o)^^2).sum);
    }
    T getDistanceSQ(const vec o) const {
        return cast(T) ((x-o.x)^^2 + (y - o.y)^^2 + (z-o.z)^^2);
        //return ((this-o)^^2).sum;
    }

    T sum() const {
        return cast(T)(x + y + z);
    }



    void rotateXYBy(double radians, vec around) {
        this -= around;
        double c = cos(radians);
        double s = sin(radians);
        double newX = x * c - y * s;
        double newY = x * s + y * c;
        x = cast(T)newX;
        y = cast(T)newY;
        this += around;
    }
    vec getHorizontalAngle() const
    {
        vec angle = void;
        angle.y = cast(T)(atan2(cast(double)x, cast(double)z) * RadToDeg);
        if (angle.y < 0)
            angle.y += 360;
        if (angle.y >= 360)
            angle.y -= 360;
        immutable z1 = sqrt(cast(real)x*x + z*z);
        angle.x = cast(T)(atan2(cast(double)z1, cast(double)y) * RadToDeg - 90.0);
        if (angle.x < 0)
            angle.x += 360;
        if (angle.x >= 360)
            angle.x -= 360;
        angle.z = 0;
        return angle;
    }    

    bool isBetweenPoints(const vec begin, const vec end) const
    {
        const T f = (end - begin).getLengthSQ();
        return getDistanceSQ(begin) <= f &&
            getDistanceSQ(end) <= f;
    }


}

struct vector2(T) {
    T x = void;
    T y = void;

    alias vector2!T vec;

    this(T _x) {
        x = y = _x;
    }
    this(T _x, T _y) {
        x = _x;
        y = _y;
    }
    this(const vec3!T o) {
        x = o.x;
        y = o.y;
    }

    void set(T _x, T _y) {
        x = _x;
        y = _y;
    }

    vec3!T v3(T z = 0) const {
        return vec3!T(x, y, z);
    }


    vec opBinary(string op, O)(const O o) const {
        vec ret = void;
        static if( is( O : vec)) {
            ret.x = cast(T) mixin("x " ~ op ~ " o.x");
            ret.y = cast(T) mixin("y " ~ op ~ " o.y");
        } else {
            ret.x = cast(T) mixin("x " ~ op ~ " o");
            ret.y = cast(T) mixin("y " ~ op ~ " o");
        }
        return ret;
    }
    void opOpAssign(string op, O)(const O o) {
        static if( is( O : vec)) {
            x = cast(T) mixin("x " ~ op ~ " o.x");
            y = cast(T) mixin("y " ~ op ~ " o.y");
        } else {
            x = cast(T) mixin("x " ~ op ~ " o");
            y = cast(T) mixin("y " ~ op ~ " o");
        }
    }

    auto convert(O)() const {
        return vector2!O( cast(O)x, cast(O)y);
    }

    ref T opIndex(size_t idx) {
        switch(idx) {
            case 0: return x;
            case 1: return y;
        }
    }


    //Rationale for this: see implementation in vec3
    void opAssign(const vec other) {
        //TODO: use standard blitting?
        x = other.x;
        y = other.y;
    }

    T dotProduct(const vec o) {
        return cast(T) (x * o.x + y * o.y);
    }

    // Not really a cross product but the result of derp.
    T crossProduct(const vec o) {
        return cast(T)( x * o.y - y * o.x);
    }

    T getLength() const {
        return cast(T)sqrt(cast(real)x^^2 + y^^2);
    }
    void setLength(T length) {
        if(x == 0 && y == 0) return;
        immutable constant = cast(T)(length / getLength());
        x *= constant;
        y *= constant;
    }

    vec normalize() {
        setLength(1);
        return this;
    }

    T getDistance(const vec o) const {
        return cast(T)sqrt(cast(real) (x-o.x)^^2 + (y - o.y)^^2);
        //return sqrt(((this-o)^^2).sum);
    }
    T getDistanceSQ(const vec o) const {
        return cast(T) ((x-o.x)^^2 + (y - o.y)^^2);
        //return ((this-o)^^2).sum;
    }

    T sum() const {
        return cast(T)(x + y);
    }

    double getAngleWith(const vec o) {
        BREAKPOINT;
        assert(0);
    }
	bool isBetweenPoints(const vec begin, const vec end) const {
		if (begin.x != end.x) {
			return ((begin.x <= x && x <= end.x) ||
                    (begin.x >= x && x >= end.x));
		} else {
			return ((begin.y <= y && y <= end.y) ||
                    (begin.y >= y && y >= end.y));
		}
	}
}


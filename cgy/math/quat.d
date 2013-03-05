module math.quat;

import math.vector;
import math.math;

import util.util : BREAK_IF;

alias quaternion!double quatd;
alias quaternion!float quatf;

struct quaternion(T) {
    T w = void;
    T x = void;
    T y = void;
    T z = void;
    alias quaternion!T quat;

    this(T _w, T _x, T _y, T _z) {
        w = _w;
        x = _x;
        y = _y;
        z = _z;
    };

    quat opBinary(string op)(const quat q) const if( op == "*") {
        quat ret = void;
        ret.w = w * q.w - x * q.x - y * q.y - z * q.z;
        ret.x = w * q.x + x * q.w + y * q.z - z * q.y;
        ret.y = w * q.y - x * q.z + y * q.w + z * q.x;
        ret.z = w * q.z + x * q.y - y * q.x + z * q.w;
        return ret;
    }

    T magnitude() const {
        immutable magSQ = w^^2 + x^^2 + y^^2 + z^^2;
        if(equals(magSQ, 1)) return 1;
        return sqrt(magSQ);
    }

    quat normalize() {
        BREAK_IF(x == 0 && y == 0 && z == 0 && w == 0);
        immutable magSQ = w^^2 + x^^2 + y^^2 + z^^2;
        if(equals(magSQ, 1)) return this;
        T invMag = 1.0 / sqrt(magSQ);
        w *= invMag;
        x *= invMag;
        y *= invMag;
        z *= invMag;
        return this;
    }

    quat conjugate() const {
        quat ret = void;
        ret.x = -x;
        ret.y = -y;
        ret.z = -z;
        ret.w =  w;
        return ret;
    }

    vec3!T rotate(const vec3!T _pt) const {
        quat pt = quat(0, _pt.tupleof);
        pt = this * pt * conjugate;
        return vec3!T(pt.x, pt.y, pt.z);
    }
    vec3!T rotateDerp(const vec3!T _pt) const {
        quat pt = quat(0, _pt.tupleof);
        pt = this * pt;// * pt.conjugate;
        return vec3!T(pt.x, pt.y, pt.z);
    }

    static quat rotationQuat(T angle, T axisX, T axisY, T axisZ) {
        immutable halfAngle = angle * 0.5;
        immutable sn = sin(halfAngle);
        immutable cs = cos(halfAngle);
        quat ret = void;
        ret.x = axisX * sn;
        ret.y = axisY * sn;
        ret.z = axisZ * sn;
        ret.w = cs;
        return ret;
    }


    auto toMatrix() const {
        import stolen.matrix4;
        matrix4 ret = void;
        immutable magSQ = w^^2 + x^^2 + y^^2 + z^^2;
        if(equals(magSQ, 1)) {
            ret[ 0] = 1 - 2 * y^^2 - 2 * z^^2;
            ret[ 1] = 2 * x * y - 2 * w * z;
            ret[ 2] = 2 * x * z + 2 * w * y;
            ret[ 3] = 0;

            ret[ 4] = 2 * x * y + 2 * w * z;
            ret[ 5] = 1 - 2 * x ^^ 2 - 2 * z ^^ 2;
            ret[ 6] = 2 * y * z + 2 * w * x;
            ret[ 7] = 0;

            ret[ 8] = 2 * x * z - 2 * w * y;
            ret[ 9] = 2 * y * z - 2 * w * y;
            ret[10] = 1 - 2 * x^^2 - w * y^^2;
            ret[11] = 0;

            ret[12] = 0;
            ret[13] = 0;
            ret[14] = 0;
            ret[15] = 1;
        } else {
            ret[ 0] = w^^2 + x^^2 - y^^2 - z^^2;
            ret[ 1] = 2 * x * y - 2 * w * z;
            ret[ 2] = 2 * x * z + 2 * w * y;
            ret[ 3] = 0;

            ret[ 4] = 2 * x * y + 2 * w * z;
            ret[ 5] = w^^2 - x^^2 + y^^2 - z^^2;
            ret[ 6] = 2 * y * z + 2 * w * x;
            ret[ 7] = 0;

            ret[ 8] = 2 * x * z - 2 * w * y;
            ret[ 9] = 2 * y * z - 2 * w * y;
            ret[10] = w^^2 - x^^2 - y^^2 + z^^2;
            ret[11] = 0;

            ret[12] = 0;
            ret[13] = 0;
            ret[14] = 0;
            ret[15] = 1;
        }
        return ret;
    }

}

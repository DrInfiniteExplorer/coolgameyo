module random.simplex;


import std.math;
import std.random;

import math.math : fastFloor;
import random.valuesource;
import util.util;


static immutable vec3i[12] gradients = [
    vec3i(1,1,0), vec3i(-1,1,0), vec3i(1,-1,0), vec3i(-1,-1,0),
    vec3i(1,0,1), vec3i(-1,0,1), vec3i(1,0,-1), vec3i(-1,0,-1),
    vec3i(0,1,1), vec3i(0,-1,1), vec3i(0,1,-1), vec3i(0,-1,-1),

];

class SimplexNoise : ValueSource {

    ubyte[512] perm;
    ubyte[512] permMod12;

    this(int seed) {
        Random gen;
        gen.seed(seed);
        foreach(idx, ref val ; perm) val = idx % 256;
        randomShuffle(perm[], gen);
        foreach(idx, val ; perm) {
                permMod12[idx] = val % 12;
        }
    }


    override double getValue3(vec3d pos) {
        BREAKPOINT;
        return double.init;
    }
    override double getValue(double x) {
        BREAKPOINT;
        return double.init;
    }

    immutable F2 = 0.5 * (sqrt(3.0) - 1.0);
    immutable G2 = (3.0 - sqrt(3.0)) / 6.0;
    T getVal2(T)(vector2!T pos) {
        pos *= 0.5; //To scale it somewhat into being more like perlin noise

        T s = (pos.x + pos.y) * cast(T)F2;

        int i = fastFloor(pos.x + s);
        int j = fastFloor(pos.y + s);

        T t = (i + j) * cast(T)G2;

        T X0 = i - t;
        T Y0 = j - t;
        T x0 = pos.x - X0;
        T y0 = pos.y - Y0;
        int i1, j1; // Offsets for second (middle) corner of simplex in (i,j) coords
        if(x0>y0) {i1=1; j1=0;} // lower triangle, XY order: (0,0)->(1,0)->(1,1)
        else {i1=0; j1=1;}      // upper triangle, YX order: (0,0)->(0,1)->(1,1)
        T x1 = x0 - i1 + cast(T)G2; // Offsets for middle corner in (x,y) unskewed coords
        T y1 = y0 - j1 + cast(T)G2;
        T x2 = x0 - 1.0 + cast(T)(2.0 * G2); // Offsets for last corner in (x,y) unskewed coords
        T y2 = y0 - 1.0 + cast(T)(2.0 * G2);
        // Work out the hashed gradient indices of the three simplex corners
        int ii = i & 255;
        int jj = j & 255;
        int gi0 = permMod12[ii+perm[jj]];
        int gi1 = permMod12[ii+i1+perm[jj+j1]];
        int gi2 = permMod12[ii+1+perm[jj+1]];

        // Calculate the contribution from the three corners
        T t0 = cast(T)0.5 - x0*x0-y0*y0;
        T n0 = void, n1 = void, n2 = void;
        if(t0<0) {
            n0 = cast(T)0.0;
        } else {
            t0 *= t0;
            n0 = t0 * t0 * (gradients[gi0].x* x0 + gradients[gi0].y * y0);  // (x,y) of grad3 used for 2D gradient
        }
        T t1 = cast(T)0.5 - x1*x1-y1*y1;
        if(t1<0) {
            n1 = cast(T)0.0;
        } else {
            t1 *= t1;
            n1 = t1 * t1 * (gradients[gi1].x * x1 + gradients[gi1].y * y1);
        }
        T t2 = cast(T)0.5 - x2*x2-y2*y2;
        if(t2<0) {
            n2 = cast(T)0.0;
        } else {
            t2 *= t2;
            n2 = t2 * t2 * (gradients[gi2].x * x2 + gradients[gi2].y * y2);
        }
        // Add contributions from each corner to get the final noise value.
        // The result is scaled to return values in the interval [-1,1].
        return cast(T)70.0 * (n0 + n1 + n2);
    }

    override double getValue2(vec2d p) {
        alias double T;
        //return getVal3(vector3!T(p.x, p.y, 0));
        return getVal2(p);
    };

    T getVal3_2d(T)(vector2!T v) {
        return getVal3(vector3!T(v.x, v.y, v.x-v.y));
    }

    immutable F3 = 1.0/3.0;
    immutable G3 = 1.0/6.0;
    T getVal3(T)(vector3!T pos) {
        T n0 = void, n1 = void, n2 = void, n3 = void;

        pos *= 0.6;
        
        T s = (pos.x+pos.y+pos.z)* cast(T)F3;
        int i = fastFloor(pos.x+s);
        int j = fastFloor(pos.y+s);
        int k = fastFloor(pos.z+s);
        T t = (i+j+k)* cast(T)G3;
        T X0 = i-t;
        T Y0 = j-t;
        T Z0 = k-t;
        T x0 = pos.x-X0;
        T y0 = pos.y-Y0;
        T z0 = pos.z-Z0;

        int i1 = void, j1 = void, k1 = void;
        int i2 = void, j2 = void, k2 = void;
        if(x0>=y0) {
            if(y0>=z0)
            { i1=1; j1=0; k1=0; i2=1; j2=1; k2=0; }
            // X Y Z order
            else if(x0>=z0) { i1=1; j1=0; k1=0; i2=1; j2=0; k2=1; }
            // X Z Y order
            else { i1=0; j1=0; k1=1; i2=1; j2=0; k2=1; }
            // Z X Y order
        }
        else {
            // x0<y0
            if(y0<z0) { i1=0; j1=0; k1=1; i2=0; j2=1; k2=1; }
            // Z Y X order
            else if(x0<z0) { i1=0; j1=1; k1=0; i2=0; j2=1; k2=1; }
            // Y Z X order
            else { i1=0; j1=1; k1=0; i2=1; j2=1; k2=0; }
            // Y X Z order
        }
        // A step of (1,0,0) in (i,j,k) means a step of (1-c,-c,-c) in (x,y,z),
        // a step of (0,1,0) in (i,j,k) means a step of (-c,1-c,-c) in (x,y,z), and
        // a step of (0,0,1) in (i,j,k) means a step of (-c,-c,1-c) in (x,y,z), where
        // c = 1/6.
        T x1 = x0 - i1 + cast(T)G3;
        // Offsets for second corner in (x,y,z) coords
        T y1 = y0 - j1 + cast(T)G3;
        T z1 = z0 - k1 + cast(T)G3;
        T x2 = x0 - i2 + cast(T)(2.0*G3);
        // Offsets for third corner in (x,y,z) coords
        T y2 = y0 - j2 + cast(T)(2.0*G3);
        T z2 = z0 - k2 + cast(T)(2.0*G3);
        T x3 = x0 + cast(T)(-1.0 + 3.0*G3);
        // Offsets for last corner in (x,y,z) coords
        T y3 = y0 + cast(T)(-1.0 + 3.0*G3);
        T z3 = z0 + cast(T)(-1.0 + 3.0*G3);
        // Work out the hashed gradient indices of the four simplex corners
        int ii = i & 255;
        int jj = j & 255;
        int kk = k & 255;
        int gi0 = permMod12[ii+permMod12[jj+permMod12[kk]]];
        int gi1 = permMod12[ii+i1+permMod12[jj+j1+permMod12[kk+k1]]];
        int gi2 = permMod12[ii+i2+permMod12[jj+j2+permMod12[kk+k2]]];
        int gi3 = permMod12[ii+1+permMod12[jj+1+permMod12[kk+1]]];
        // Calculate the contribution from the four corners
        T t0 = cast(T)0.6 - x0*x0 - y0*y0 - z0*z0;
        if(t0<0) n0 = cast(T)0.0;
        else {
            t0 *= t0;
            n0 = t0 * t0 * (gradients[gi0].x * x0 + gradients[gi0].y * y0 + gradients[gi0].z * z0);
        }
        T t1 = cast(T)0.6 - x1*x1 - y1*y1 - z1*z1;
        if(t1<0) n1 = cast(T)0.0;
        else {
            t1 *= t1;
            n1 = t1 * t1 * (gradients[gi1].x * x1 + gradients[gi1].y * y1 + gradients[gi1].z * z1);
        }
        T t2 = cast(T)0.6 - x2*x2 - y2*y2 - z2*z2;
        if(t2<0) n2 = cast(T)0.0;
        else {
            t2 *= t2;
            n2 = t2 * t2 * (gradients[gi2].x * x2 + gradients[gi2].y * y2 + gradients[gi2].z * z2);
        }
        T t3 = cast(T)0.6 - x3*x3 - y3*y3 - z3*z3;
        if(t3<0) n3 = cast(T)0.0;
        else {
            t3 *= t3;
            n3 = t3 * t3 * (gradients[gi3].x * x3 + gradients[gi3].y * y3 + gradients[gi3].z * z3);
        }
        // Add contributions from each corner to get the final noise value.
        // The result is scaled to stay just inside [-1,1]
        return cast(T)32.0 * (n0 + n1 + n2 + n3);
    }

}

// for profiling simplex
shared static this() {
    auto simplex = new SimplexNoise(5134);
    auto end = mstime() + 1000 * 60 * 0;
    auto pos = vec2f(0.1);
    while(mstime() < end) {
        pos.x += simplex.getVal2(pos);
        pos.y -= simplex.getVal2(pos);
    }
    import std.stdio;
    writeln("done");
}



unittest {
    import std.stdio;
    import std.conv;

    static auto fastFloor(double val) {
        int ret = cast(int)val;
        return val < ret ? ret - 1 : ret;
    }
    msg(fastFloor(1.5));
    msg(fastFloor(0.5));
    msg(fastFloor(-0.5));
    msg(fastFloor(-1.5));
    msg(fastFloor(-1.5));

    auto simplex = new SimplexNoise(5134);
    double min = double.max;
    double max = -double.max;
    for(double t = 0; t < 123456; t += 0.1) {
        double v = simplex.getValue2(vec2d(t,t+simplex.getValue2(vec2d(t, t))));
        if (min > v) min = v;
        if (max < v) max = v;
    }
    writeln("Simplex unit test: min ", min, " max ", max);
    assert(max - min > 1.5, text("Derp derp lskjdflu blommorna brinner! ", max-min));


/*
    // For testing if unpredictableSeed really is unpredictable. Seems like it atm 2013-02
    typeof(unpredictableSeed())[100] asd;
    foreach(i ; 0 .. 100) {
        asd[i] = unpredictableSeed;
    }
    foreach(dsa ; asd) {
        msg(dsa);
    }
    msg("derp");
*/


}

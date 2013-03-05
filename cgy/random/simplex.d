module random.simplex;


import std.math;
import std.random;

import random.valuesource;
import util.math;
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
    override double getValue2(vec2d pos) {
        pos *= 0.5; //To scale it somewhat into being more like perlin noise

        auto s = (pos.x + pos.y) * F2;

        int i = fastFloor(pos.x + s);
        int j = fastFloor(pos.y + s);

        double t = (i + j) * G2;

        double X0 = i - t;
        double Y0 = j - t;
        double x0 = pos.x - X0;
        double y0 = pos.y - Y0;
        int i1, j1; // Offsets for second (middle) corner of simplex in (i,j) coords
        if(x0>y0) {i1=1; j1=0;} // lower triangle, XY order: (0,0)->(1,0)->(1,1)
        else {i1=0; j1=1;}      // upper triangle, YX order: (0,0)->(0,1)->(1,1)
        double x1 = x0 - i1 + G2; // Offsets for middle corner in (x,y) unskewed coords
        double y1 = y0 - j1 + G2;
        double x2 = x0 - 1.0 + 2.0 * G2; // Offsets for last corner in (x,y) unskewed coords
        double y2 = y0 - 1.0 + 2.0 * G2;
        // Work out the hashed gradient indices of the three simplex corners
        int ii = i & 255;
        int jj = j & 255;
        int gi0 = permMod12[ii+perm[jj]];
        int gi1 = permMod12[ii+i1+perm[jj+j1]];
        int gi2 = permMod12[ii+1+perm[jj+1]];


        static auto dot(T)(const ref T t, double x, double y) {
            return t.x * x + t.y * y;
        }

        // Calculate the contribution from the three corners
        double t0 = 0.5 - x0*x0-y0*y0;
        double n0 = void, n1 = void, n2 = void;
        if(t0<0) {
            n0 = 0.0;
        } else {
            t0 *= t0;
            n0 = t0 * t0 * dot(gradients[gi0], x0, y0);  // (x,y) of grad3 used for 2D gradient
        }
        double t1 = 0.5 - x1*x1-y1*y1;
        if(t1<0) {
            n1 = 0.0;
        } else {
            t1 *= t1;
            n1 = t1 * t1 * dot(gradients[gi1], x1, y1);
        }
        double t2 = 0.5 - x2*x2-y2*y2;
        if(t2<0) {
            n2 = 0.0;
        } else {
            t2 *= t2;
            n2 = t2 * t2 * dot(gradients[gi2], x2, y2);
        }
        // Add contributions from each corner to get the final noise value.
        // The result is scaled to return values in the interval [-1,1].
        return 70.0 * (n0 + n1 + n2);
    }


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

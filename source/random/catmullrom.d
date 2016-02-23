module random.catmullrom;

import std.algorithm.comparison : clamp;
import std.conv;
import std.exception;
import std.traits;

import math.math;
import random.random;
import util.util;


// The Catmull Rom spline is a spline that is C2-continous spline.
// Wikipedia redirects "catmull rom" to "cubic hermite spline", since catmull-rom is
//  a specialcase of CHS with well defined tangents.
// Catmull-Rom is often used to interpolate between keyframes, such as camera movement.
// My experiments in the color spline menu led me to conclude that it is now convex,
//  ie. it overshoots, which is not always awesome.
// It's also local and interpolating.

//  Some sources of information
// http://en.wikipedia.org/wiki/Cubic_Hermite_spline
// http://www.cs.clemson.edu/~dhouse/courses/405/notes/splines.pdf

//Dynamic version
Unqual!Type CatmullRomSpline(Type)(double t, Type[] ar)
in{
    enforce(ar.length >= 4, "Can't do catmull-rom with less than 4 control points!");
}
body{    
    if(ar.length == 4) {
        auto c3 = -0.5 * ar[0] +  1.5 * ar[1] + -1.5 * ar[2] +  0.5 * ar[3];
        auto c2 =  1.0 * ar[0] + -2.5 * ar[1] +  2.0 * ar[2] + -0.5 * ar[3];
        auto c1 = -0.5 * ar[0] +                 0.5 * ar[2];
        auto c0 =                 1.0 * ar[1];
    
        return cast(Unqual!Type)  (((c3*t + c2)*t + c1)*t + c0);
    } else {
        int count = cast(int)ar.length;
        int nspans = count-3;
    
        double x = clamp(t, 0.0, 1.0) * to!double(nspans);
        int span = cast(int)x;
        if (span >= count - 3) {
            span = count - 3;
        }
        x -= span;
        Type* knot = &ar[span];
        auto c3 = -0.5 * knot[0] +  1.5 * knot[1] + -1.5 * knot[2] +  0.5 * knot[3];
        auto c2 =  1.0 * knot[0] + -2.5 * knot[1] +  2.0 * knot[2] + -0.5 * knot[3];
        auto c1 = -0.5 * knot[0] +                   0.5 * knot[2];
        auto c0 =                   1.0 * knot[1];
    
        return cast(Unqual!Type) (((c3*x + c2)*x + c1)*x + c0);
    }
}


//Compile-time version
CommonType!(Type) CatmullRomSpline(Type...)(double t)
body{
    static if(Type.length < 4) {
        pragma(msg, "Need at least 4 control points.");        
    } else static if(Type.length == 4) {
        auto c3 = -0.5 * Type[0] +  1.5 * Type[1] + -1.5 * Type[2] +  0.5 * Type[3];
        auto c2 =  1.0 * Type[0] + -2.5 * Type[1] +  2.0 * Type[2] + -0.5 * Type[3];
        auto c1 = -0.5 * Type[0] +                 0.5 * Type[2];
        auto c0 =                 1.0 * Type[1];
    
        return ((c3*t + c2)*t + c1)*t + c0;
    } else {
        int count = Type.length;
        int spans = count-3;
    
        double x = clamp(t, 0, 1) * to!double(spans);
        int span = to!int(x);
        if (span > count - 3) {
            BREAKPOINT;
            span = count - 3;
        }
        x -= to!int(span);
        Type* knot = &Type[span];
        auto c3 = -0.5 * knot[0] +  1.5 * knot[1] + -1.5 * knot[2] +  0.5 * knot[3];
        auto c2 =  1.0 * knot[0] + -2.5 * knot[1] +  2.0 * knot[2] + -0.5 * knot[3];
        auto c1 = -0.5 * knot[0] +                   0.5 * knot[2];
        auto c0 =                   1.0 * knot[1];
    
        return ((c3*x + c2)*x + c1)*x + c0;
    }
}


immutable vec3d[5] temperatureSpline = [vec3d(0, 0, 1), vec3d(0, 0, 1), vec3d(1, 1, 0), vec3d(1, 0, 0), vec3d(1, 0, 0)];

double[4] delegate(double) colorSpline(Type)(Type[] ar) {
    return (double d) {
        union Asd {
            double[4] ret;
            Unqual!Type tmp;
        }
        Asd asd;
        asd.tmp = CatmullRomSpline(d, ar);
        return asd.ret;
    };
} 

module random.catmullrom;

import std.conv;
import std.exception;
import std.traits;

import util.util;
import random.random;

//Dynamic version
Type CatmullRomSpline(Type)(double t, Type[] ar)
in{
    enforce(ar.length >= 4, "Can't do catmull-rom with less than 4 control points!");
}
body{    
    if(ar.length == 4) {
        auto c3 = -0.5 * ar[0] +  1.5 * ar[1] + -1.5 * ar[2] +  0.5 * ar[3];
        auto c2 =  1.0 * ar[0] + -2.5 * ar[1] +  2.0 * ar[2] + -0.5 * ar[3];
        auto c1 = -0.5 * ar[0] +                 0.5 * ar[2];
        auto c0 =                 1.0 * ar[1];
    
        return ((c3*t + c2)*t + c1)*t + c0;
    } else {
        int count = ar.length;
        int spans = count-3;
    
        double x = clamp(t, 0, 1) * to!double(spans);
        int span = to!int(x);
        if (span > count - 3) {
            BREAKPOINT;
            span = count - 3;
        }
        x -= to!int(span);
        Type* knot = &ar[span];
        auto c3 = -0.5 * knot[0] +  1.5 * knot[1] + -1.5 * knot[2] +  0.5 * knot[3];
        auto c2 =  1.0 * knot[0] + -2.5 * knot[1] +  2.0 * knot[2] + -0.5 * knot[3];
        auto c1 = -0.5 * knot[0] +                   0.5 * knot[2];
        auto c0 =                   1.0 * knot[1];
    
        return ((c3*x + c2)*x + c1)*x + c0;
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


module random.random;

import std.algorithm;
//import math.math : clamp;
import std.conv;
import std.exception;
import std.functional : ParameterTypeTuple;
import std.math;
import std.random;
import std.stdio;
import std.typecons;

import graphics.image;
import util.util;



T lerpCorrect(T)(T x0, T x1, double t) {
    return (1.0 - t) * x0 + t * x1;
}
T lerpCorrect(T, T x0, T x1)(double t) {
    return (1.0 - t) * x0 + t * x1;
}
T lerpFast(T)(T x0, T x1, double t) {
    const d = x1 - x0;
    return x0 + t * d;
}
T lerpFast(T, T x0, T x1)(double t) {
    immutable d = x1 - x0;
    return x0 + t * d;
}
alias lerpFast lerp;

//Also called "hermite curve smooth transition" (Texturing/modelling - a procedural aproach p. 166)
double smoothStep(double time) {
    return time*time * (3 - 2 * time); 
}
double smootherStep(double time) {
    return time*time*time * (10 + time*(-15 + time*6)); 
}

double cosStep(double time) {
    float tmp = (1.0-cos(time*PI))/2.0; //TODO: Make fancy cos-table? mayhaps? interpolate in table? :)
    return tmp;
}

double rampStep(double time) {
    return clamp(time, 0.0, 1.0);
}

T CosInter(T)(T x0, T x1, double time){
    return lerp!T(x0, x1, cosStep(time));
}

T SmoothInter(T)(T x0, T x1, double time) {
    return lerp!T(x0, x1, smoothStep(time));
}
T SmootherInter(T)(T x0, T x1, double time) {
    return lerp!T(x0, x1, smootherStep(time));
}



/*
T CubicInter(T)(T x0, T x1, T x2, T x3, double time) {
    return x1 + 0.5 * time*(x2 - x0 + time*(2.0*x0 - 5.0*x1 + 4.0*x2 - x3 + time*(3.0*(x1 - x2) + x3 - x0)));
}

*/

//Cubic interpolation seems to be non-convex, ie. causes overshoot. It is interpolating,
// and c2-continous.

T CubicInter(T)(
                        T y0,T y1,
                        T y2,T y3,
                        double mu)
{
    T a0 = void,a1 = void,a2 = void,a3 = void;
    double mu2 = void;

    mu2 = mu*mu;
    a0 = y3 - y2 - y0 + y1;
    a1 = y0 - y1 - a0;
    a2 = y2 - y0;
    a3 = y1;

    return(a0*mu*mu2+a1*mu2+a2*mu+a3);
}

unittest{
    BREAK_IF( CubicInter(0.0, 1.0, 2.0, 0.0, 0.0) != 1.0);
    BREAK_IF( CubicInter(0.0, 1.0, 2.0, 0.0, 1.0) != 2.0);
}


//B-splines are stable and convex and awesome?
// mu goes from 0 to 1 and interpolates between x1 and x2
T BSpline(T)(T x0, T x1, T x2, T x3, double t) {
    return (x0 + 4*x1 + x2 + t*( 3*(x2 - x0) +  t*( 3*(x0 + x2) - 6*x1 + t*(-x0 + 3*(x1 - x2) + x3)))) / 6.0;
}
unittest{
    // Should not be same as CubicInter since convex interpolation.
//    BREAK_IF( BSpline(0.0, 1.0, 2.0, 0.0, 0.0) != 1.0);
//    BREAK_IF( BSpline(0.0, 1.0, 2.0, 0.0, 1.0) != 2.0);

}

// Takes a mixer (for example b-spline or cubicinter), an array of values and a time between 0 and 1.
// The result is an interpolated value from the array. Guess you didn't see that comming.
// Note that this function does not interpolate to the endpoint values; they are just used for the gradient
// at the ends.
auto Knotify(alias Mixer, T, V)(T t, V[] ar) {
    alias ParameterTypeTuple!(Mixer!V) mixerArgs;
    enum AlmostSpanSize = mixerArgs.length - 2;
    static assert(AlmostSpanSize == 1 || AlmostSpanSize == 3, "Bad mixer. Something should be done.");
    int count = cast(int)ar.length;
    int nspans = count-AlmostSpanSize;

    double x = clamp(cast(double)t, 0.0, 1.0) * cast(double)nspans;
    int span = cast(int)x;
    if (span >= count - AlmostSpanSize) {
        span = count - AlmostSpanSize;
    }
    x -= span;
    V* knot = &ar[span];
    static if(mixerArgs.length == 5) {
        return Mixer(knot[0], knot[1], knot[2], knot[3], x);
    } else {
        return Mixer(knot[0], knot[1], x);
    }

}

auto Interpolate(alias Mixer, bool extend = false, T, V)(T t, V[] ar) if( 5 == ParameterTypeTuple!(Mixer!V).length ) {

    immutable int span = 3;
    double pos = cast(double)t * (ar.length-1);
    int idx = cast(int)pos;

    double local = pos - idx;

    static if(extend) {
        if(idx == 0) {
            return Mixer(2*ar[0]-ar[1], ar[0], ar[1], ar[2], local);
        } else if(idx >= ar.length - 2) {
            idx = cast(int)ar.length-2;
            return Mixer(ar[idx-1], ar[idx], ar[idx+1], 2*ar[idx+1]-ar[idx], local);
        }
    } else {
        if(idx == 0) {
            return Mixer(ar[0], ar[0], ar[1], ar[2], local);
        } else if(idx >= ar.length - 2) {
            idx = cast(int)ar.length-2;
            return Mixer(ar[idx-1], ar[idx], ar[idx+1], ar[idx+1], local);
        }
    }
    return Mixer(ar[idx-1], ar[idx], ar[idx+1], ar[idx+2], local);
}

auto Interpolate(alias Mixer, bool extend = false, T, V)(T t, V[] ar) if( 3 == ParameterTypeTuple!(Mixer!V).length ) {
    immutable int span = 1;
    double pos = cast(double)t * (ar.length-1);
    int idx = cast(int)pos;
    double local = pos - idx;
    return Mixer(ar[idx], ar[idx+1], local);
}


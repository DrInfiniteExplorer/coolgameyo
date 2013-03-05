
module random.random;

import std.algorithm;
import std.conv;
import std.exception;
import std.math;
import std.random;
import std.stdio;
import std.typecons;

import graphics.image;
import util.util;
import util.math;



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
    T a0,a1,a2,a3;
    double mu2;

    mu2 = mu*mu;
    a0 = y3 - y2 - y0 + y1;
    a1 = y0 - y1 - a0;
    a2 = y2 - y0;
    a3 = y1;

    return(a0*mu*mu2+a1*mu2+a2*mu+a3);
}


//B-splines are stable and convex and awesome?
// mu goes from 0 to 1 and interpolates between x1 and x2
T BSpline(T)(T x0, T x1, T x2, T x3, double t) {
    return (x0 + 4*x1 + x2 + t*( 3*(x2 - x0) +  t*( 3*(x0 + x2) - 6*x1 + t*(-x0 + 3*(x1 - x2) + x3)))) / 6.0;
}






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


//TODO: Make interface, etc laters


auto getValue(Source)(Source s, double x, double y) {
    static if(__traits(compiles, s.getValue(x, y))) {    
        return s.getValue(x, y);
    } else static if(__traits(compiles, s(x, y))) {
        return s(x, y);
    } else {
        pragma(error, "error error error");
        pragma(msg, "Error: Cant use type ", Source, " as a value source");
        assert(0);
    }
}
auto getValue(Source)(Source s, double x) {
    static if(__traits(compiles, s.getValue(x))) {    
        return s.getValue(x);
    } else static if(__traits(compiles, s(x))) {
        return s(x);
    } else {
        pragma(error, "error error error");
        pragma(msg, "Error: Cant use type ", Source, " as a value source");
        assert(0);
    }
}




double clamp(double value, double _min, double _max) {
    return min(_max, max(_min, value));
}

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
    enum d = x1 - x0;
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
    return clamp(time, 0, 1);
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


T BicubeInter(T)(T x0, T x1, T x2, T x3, double time) {
    return x1 + 0.5 * time*(x2 - x0 + time*(2.0*x0 - 5.0*x1 + 4.0*x2 - x3 + time*(3.0*(x1 - x2) + x3 - x0)));
}

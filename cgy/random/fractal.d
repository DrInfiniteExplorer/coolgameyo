module random.fractal;

import std.math;

import random.random;

class Fractal(uint Count) : ValueSource { //TODO: Think of better name than Fractal
    ValueSource[Count] sources;
    double[Count] freqs;
    double[Count] amps;
    //The period is 1/freq
    this(ValueSource[Count] s, double[Count] period, double[Count] a) {
        sources = s;
        freqs = 1.0 / period[];
        amps = a;
    }
    
    double getValue3(vec3d pos) {
        double ret = 0;
        foreach(idx; 0 .. Count) {
            auto freq = freqs[idx];
            auto amp = amps[idx];
            ret += sources[idx].getValue(x * freq, y * freq, z * freq) * amp;
        }
        return ret;
    }
    double getValue2(vec2d pos) {
        double ret = 0;
        foreach(idx; 0 .. Count) {
            auto freq = freqs[idx];
            auto amp = amps[idx];
            ret += sources[idx].getValue(x * freq, y * freq) * amp;
        }
        return ret;
    }
    double getValue(double x) {    
        double ret = 0;
        foreach(idx; 0 .. Count) {
            auto freq = freqs[idx];
            auto amp = amps[idx];
            ret += sources[idx].getValue(x * freq) * amp;
        }
        return ret;
    }    
}


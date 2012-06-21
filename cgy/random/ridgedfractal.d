module random.ridgedfractal;

import std.math;

import random.valuesource;

// TMPA p504
final class RidgedMultiFractal : ValueSource {
    ValueSource source;
    double H = 0.75;
    double lacunarity = 2.0;
    double offset = 0.5;
    double octaves = 8.0;
    double gain = 1.0;
    double baseFrequency = 1.0;

    double[] exponents;

    /*
    H is a fractal dimension parameter, see TMPA p438  H=0 -> smooth ; H=1 -> whitenoise
    lacunarity is how much the spatial frequency increase per octave. multiplicative, cummulative per iteration. usually 2.
    octaves is number of iterations
    offset is added to the basis function each iteration. Causes stuff to explode!
    gain is what? :S
    */
    this(ValueSource s) {
        source = s;
    }
    this(ValueSource s, double _H, double _lacunarity, double _octaves, double _offset, double _gain) {
        source = s;
        H = _H;
        lacunarity = _lacunarity;
        octaves = _octaves;
        offset = _offset;
        gain = _gain;

        init();
    }

    private void init() {
        exponents.length = cast(int)octaves;
        double frequency = 1.0;
        foreach( int i ; 0 .. cast(int)octaves) {
            exponents[i] = frequency ^^ -H;
            frequency *= lacunarity;
        }
    }

    void setBaseWaveLength(double waveLength) {
        baseFrequency = 1.0 / waveLength;
    }

    override double getValue(double x, double y, double z) {
        x *= baseFrequency;
        y *= baseFrequency;
        z *= baseFrequency;

        double signal = source.getValue(x, y, z);
        signal = offset - abs(signal);
        signal *= signal; //Increase sharpness of rigdes
        double result = signal;
        double weight = 1.0;
        foreach(int i; 1 .. cast(int)octaves) {
            x *= lacunarity; y *= lacunarity; z *= lacunarity;
            weight = signal * gain;
            if (weight > 1) weight = 1;
            if (weight < 0) weight = 0;
            signal = source.getValue(x, y, z);
            signal = offset - abs(signal);
            signal *= signal; //Increase sharpness of rigdes
            signal *= weight;

            result += signal * exponents[i];
        }
        return result;
    }
    override double getValue(double x, double y) {
        x *= baseFrequency;
        y *= baseFrequency;

        double signal = source.getValue(x, y);
        signal = offset - abs(signal);
        signal *= signal; //Increase sharpness of rigdes
        double result = signal;
        double weight = 1.0;
        foreach(int i; 1 .. cast(int)octaves) {
            x *= lacunarity; y *= lacunarity;
            weight = signal * gain;
            if (weight > 1) weight = 1;
            if (weight < 0) weight = 0;
            signal = source.getValue(x, y);
            signal = offset - abs(signal);
            signal *= signal; //Increase sharpness of rigdes
            signal *= weight;

            result += signal * exponents[i];
        }
        return result;
    }
    override double getValue(double x) {    
        x *= baseFrequency;

        double signal = source.getValue(x);
        signal = offset - abs(signal);
        signal *= signal; //Increase sharpness of rigdes
        double result = signal;
        double weight = 1.0;
        foreach(int i; 1 .. cast(int)octaves) {
            x *= lacunarity;
            weight = signal * gain;
            if (weight > 1) weight = 1;
            if (weight < 0) weight = 0;
            signal = source.getValue(x);
            signal = offset - abs(signal);
            signal *= signal; //Increase sharpness of rigdes
            signal *= weight;

            result += signal * exponents[i];
        }
        return result;
    }    
}

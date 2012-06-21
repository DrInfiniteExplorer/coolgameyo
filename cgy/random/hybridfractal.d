module random.hybridfractal;

import std.math;

import random.valuesource;

// TMPA p502
final class HybridMultiFractal : ValueSource {
    ValueSource source;
    double H = 0.25;
    double lacunarity = 2;
    double offset = 0.7;
    double octaves = 12;
    double baseFrequency = 1.0;

    double[] exponents;

    /*
    H is a fractal dimension parameter, see TMPA p438  H=0 -> smooth ; H=1 -> whitenoise
    lacunarity is how much the spatial frequency increase per octave. multiplicative, cummulative per iteration. usually 2.
    octaves is number of iterations
    offset is added to the basis function each iteration. Causes stuff to explode!
    */
    this(ValueSource s, double _H, double _lacunarity, double _octaves, double _offset) {
        source = s;
        H = _H;
        lacunarity = _lacunarity;
        octaves = _octaves;
        offset = _offset;

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
        double result = (source.getValue(x, y, z) + offset) * exponents[0]; //[0] should be 1...
        double weight = result;
        x *= lacunarity; y *= lacunarity; z *= lacunarity;
        foreach(int i; 1 .. cast(int)octaves) {
            if (weight > 1) weight = 1;
            double value = (source.getValue(x, y, z) + offset) * exponents[i];

            result += weight * value;
            weight *= value;
            x *= lacunarity; y *= lacunarity; z *= lacunarity;
        }
        return result;
    }
    override double getValue(double x, double y) {
        x *= baseFrequency;
        y *= baseFrequency;
        double result = (source.getValue(x, y) + offset) * exponents[0]; //[0] should be 1...
        double weight = result;
        x *= lacunarity; y *= lacunarity;
        foreach(int i; 1 .. cast(int)octaves) {
            if (weight > 1) weight = 1;
            double value = (source.getValue(x, y) + offset) * exponents[i];

            result += weight * value;
            weight *= value;
            x *= lacunarity; y *= lacunarity;

        }
        return result;
    }
    override double getValue(double x) {    
        x *= baseFrequency;
        double result = (source.getValue(x) + offset) * exponents[0]; //[0] should be 1...
        double weight = result;
        x *= lacunarity;
        foreach(int i; 1 .. cast(int)octaves) {
            if (weight > 1) weight = 1;
            double value = (source.getValue(x) + offset) * exponents[i];

            result += weight * value;
            weight *= value;
            x *= lacunarity;

        }
        return result;
    }    
}


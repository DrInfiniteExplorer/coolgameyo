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
    
    double getValue(double x, double y, double z) {
        double ret = 0;
        foreach(idx; 0 .. Count) {
            auto freq = freqs[idx];
            auto amp = amps[idx];
            ret += sources[idx].getValue(x * freq, y * freq, z * freq) * amp;
        }
        return ret;
    }
    double getValue(double x, double y) {
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

class Filter(alias f) : ValueSource { //TODO: Think of better name than Fractal
    ValueSource source;
    this(ValueSource s) {
        source = s;
    }
    
    double getValue(double x, double y, double z) {
        return f(source.getValue(x, y, z));
    }
    double getValue(double x, double y) {
        return f(source.getValue(x, y));
    }
    double getValue(double x) {
        return f(source.getValue(x));
    }    
}

class MultMultMult : ValueSource { //TODO: Think of better name than Fractal
    ValueSource source;
    ValueSource source2;
    this(ValueSource s, ValueSource s2) {
        source = s;
        source2 = s2;
    }
    
    double getValue(double x, double y, double z) {
        return source.getValue(x, y, z)*source.getValue(x, y, z);
    }
    double getValue(double x, double y) {
        return source.getValue(x, y)*source.getValue(x, y);
    }
    double getValue(double x) {
        return source.getValue(x)*source.getValue(x);
    }    
}

// TMPA p502
class HybridMultiFractal : ValueSource {
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

    void setBaseWavelength(double waveLength) {
        baseFrequency = 1.0 / waveLength;
    }


    double getValue(double x, double y, double z) {
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
    double getValue(double x, double y) {
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
    double getValue(double x) {    
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


// TMPA p504
class RidgedMultiFractal : ValueSource {
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

    void setBaseWavelength(double waveLength) {
        baseFrequency = 1.0 / waveLength;
    }

    double getValue(double x, double y, double z) {
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
    double getValue(double x, double y) {
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
    double getValue(double x) {    
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

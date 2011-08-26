
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

alias ValueMap2D!double ValueMap2Dd;

interface ValueSource {
    double getValue(double x, double y, double z);
    double getValue(double x, double y);
    double getValue(double x);
}

class RandSourceUniform : ValueSource {
    Random gen;
    double min, max;
    this(uint seed, double _min = -1.0, double _max = 1.0) {
        gen.seed(seed);
        min = _min;
        max = _max;
    }
    double getValue(double x, double y, double z) {
        return getValue(x);
    }
    double getValue(double x, double y) {
        return getValue(x);
    }
    double getValue(double x) {
        return uniform(min, max, gen);
    }
    Type get(Type)(Type miin, Type maax) {
        auto v = uniform(miin, maax, gen);
        return v;
    }
}


void foo(asd)(asd dsa) {
    writeln(dsa);
    static if(__traits(compiles,dsa.getValue)) {
        writeln(dsa.getValue(2,3));
        writeln("lolol");
    }
}

double getValue(Source)(Source s, double x, double y) {
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
double getValue(Source)(Source s, double x) {
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

unittest {
    foo("foo"); //--> foo
    foo(1); //--> 1
    foo(1.f); //--> 1
    foo(1.0); //--> 1
    auto a = new ValueMap2Dd;
    a.fill((double x, double y){return 1.0;}, 1, 1);
    foo(a); //--> foo, divide-by-0-error because no fill, lolol
}

Image toImage(ValueSource source, double lx, double ly, double hx, double hy, uint px, uint py, double low, double high,
              double[4] delegate(double) color = null){
    ValueMap2Dd map = new ValueMap2Dd();
    auto rx = (hx - lx) / to!double(px);
    auto ry = (hy - ly) / to!double(py);
    map.fill((double  x, double y)
             {
                 auto xx = lx + rx * x;
                 auto yy = ly + ry * y;
                 return source.getValue(xx, yy);
             }
             , px, py);
    return map.toImage(low, high, true, color);
}

class ModMultAdd(double mult, double offset) : ValueSource {
    ValueSource source;
    double mi = double.max;
    double ma = -double.max;
    this(ValueSource s) {
        source = s;
    }
    
    ~this(){
        writeln(mi, " ", ma);
        writeln("====");
    }
    
    double getValue(double x, double y, double z) {
        auto v = source.getValue(x, y, z) * mult + offset;
        mi = min(mi, v);
        ma = max(ma, v);
        return v;
    }
    
    double getValue(double x, double y) {
        auto v = source.getValue(x, y) * mult + offset;
        mi = min(mi, v);
        ma = max(ma, v);
        return v;
    }
    double getValue(double x) {
        auto v = source.getValue(x) * mult + offset;
        mi = min(mi, v);
        ma = max(ma, v);
        return v;
    }
}


double clamp(double value, double _min, double _max) {
    return min(_max, max(_min, value));
}

double lerp(double x0, double x1, double t) {
    return (1.0 - t) * x0 + t * x1;
}

double smoothStep(double time) {
    return time*time * (3 - 2 * time); 
}

double cosStep(double time) {
    float tmp = (1.0-cos(time*PI))/2.0; //TODO: Make fancy cos-table? mayhaps? interpolate in table? :)
    return tmp;
}

double rampStep(double time) {
    return clamp(time, 0, 1);
}

double CosInter(double x0, double x1, double time){
    return lerp(x0, x1, cosStep(time));
}

double CosineInterpolate(ValueSource source, double x, double y, double z) {
    //TODO: Do not assume that the source is a lattice with grid of size 1,1
    // Ie. dX dY may span [0, 1] over a range that is 4 long instead of current length 1.
    int loX = to!int(floor(x));
    int loY = to!int(floor(y));
    int loZ = to!int(floor(z));
    
    float dX = x - to!float(loX);
    float dY = y - to!float(loY);
    float dZ = z - to!float(loZ);
    
    double v000 = source.getValue(loX  , loY  , loZ  );
    double v100 = source.getValue(loX+1, loY  , loZ  );
    double v010 = source.getValue(loX  , loY+1, loZ  );
    double v110 = source.getValue(loX+1, loY+1, loZ  );
    double v001 = source.getValue(loX  , loY  , loZ+1);
    double v101 = source.getValue(loX+1, loY  , loZ+1);
    double v011 = source.getValue(loX  , loY+1, loZ+1);
    double v111 = source.getValue(loX+1, loY+1, loZ+1);
    
    auto v00 = CosInter(v000, v001, dZ);
    auto v01 = CosInter(v010, v011, dZ);
    auto v11 = CosInter(v110, v111, dZ);
    auto v10 = CosInter(v100, v101, dZ);
    
    auto v0 = CosInter(v00, v01, dY);
    auto v1 = CosInter(v10, v11, dY);

    return CosInter(v0, v1, dX);
}

double CosineInterpolate(ValueSource source, double x, double y) {
    //TODO: Do not assume that the source is a lattice with grid of size 1,1
    // Ie. dX dY may span [0, 1] over a range that is 4 long instead of current length 1.
    int loX = to!int(floor(x));
    int loY = to!int(floor(y));
    
    float dX = x - to!float(loX);
    float dY = y - to!float(loY);

    auto tx1 = CosInter(source.getValue(loX, loY),   source.getValue(loX+1, loY), dX);
    auto tx2 = CosInter(source.getValue(loX, loY+1), source.getValue(loX+1, loY+1), dX);
    return CosInter(tx1, tx2, dY);
}

double CosineInterpolate(ValueSource source, double x) {
    //TODO: Do not assume that the source is a lattice with grid of size 1,1
    // Ie. dX dY may span [0, 1] over a range that is 4 long instead of current length 1.
    int loX = to!int(floor(x));
    
    float dX = x - to!float(loX);
    auto tx1 = CosInter(source.getValue(loX),   source.getValue(loX+1), dX);
    return tx1;
}


class CosInterpolation : ValueSource{
    ValueSource source;
/*
    this() {
        source = new Source;
    }
*/    
    this(ValueSource _source) {
        source = _source;
    }
    double getValue(double x, double y, double z) {
        return CosineInterpolate(source, x, y, z);
    }
    double getValue(double x, double y) {
        return CosineInterpolate(source, x, y);
    }
    double getValue(double x) {
        return CosineInterpolate(source, x);
    }
}

class ValueMap2D(StorageType, bool Wrap = true) : ValueSource {
    
    StorageType[] randMap;
    uint sizeX, sizeY;
        
    void fill(Source)(Source source, uint _sizeX, uint _sizeY) {
        sizeX = _sizeX;
        sizeY = _sizeY;
        auto mul = sizeX * sizeY;
        randMap.length = mul;
        foreach(i ; 0 .. mul) {
            randMap[i] = random.random.getValue(source, to!double(i / sizeX), to!double(i % sizeX));
        }
    }
    
    StorageType getValue(double x, double y, double z) {
        return getValue(x, y);
    }
    StorageType getValue(double x, double y) {
        static if(Wrap) {
            x = posMod(to!int(x), sizeX);
            y = posMod(to!int(y), sizeY);
        }
        return randMap[to!uint(y) * sizeX + to!uint(x)];
    }

    StorageType getValue(double x) {
        static if(Wrap) {
            x = posMod(to!int(x), sizeX * sizeY);
        }
        return randMap[to!uint(x)];
    }

    
    Image toImage(StorageType min, StorageType max, bool doClamp = true, double[4] delegate(double) color = null) {
        ubyte[] imgData;
        imgData.length = 4 * sizeX * sizeY;
        ubyte* ptr = imgData.ptr;
        auto range = max - min;
        foreach(value ; randMap) {
            value = (value-min) / range;
            if (color is null ) {
                if(doClamp) {
                    value = clamp(value, 0, 1);
                }
                ptr[0..3] = to!ubyte(255 * value);
            } else {
                auto v = color(value);
                if(doClamp) {
                    foreach(ref vv; v) {
                        vv = clamp(vv, 0, 1);
                    }
                }
                ptr[0] = to!ubyte(255 * v[0]);
                ptr[1] = to!ubyte(255 * v[1]);
                ptr[2] = to!ubyte(255 * v[2]);
                ptr[3] = to!ubyte(255 * v[3]);
            }
            ptr += 4;
        }
        auto img = Image(imgData.ptr, sizeX, sizeY);
        return img;        
    }
    
    void saveAsImage(string imgName, StorageType min, StorageType max, bool clamp = true) {
        auto img = toImage(min, max, clamp);
        img.save(imgName);
    }
};

mixin template Permutation(alias SIZE) {
    uint[] permutations;
    
    void initPermutations(RandSourceUniform rsu) {
        permutations.length = SIZE;
        uint[] src;
        src.length = SIZE;
        foreach( i ; 0 .. SIZE){
            src[i] = i;
        }
        foreach( i ; 0 .. SIZE-1){
            uint idx = rsu.get!uint(0, SIZE-i-1);
            permutations[i] = src[idx];
            src[idx] = src[SIZE-i-1];
        }
        permutations[SIZE-1] = src[0];
    }
    
    uint Perm(int i) {
        return permutations[posMod(i, SIZE)]; //Move posmod to getValue, cast to uint, then use % ?
    }
    
    uint Index(int i, int j, int k) {
        return Perm( i + Perm(j + Perm(k)));
    }
    uint Index(int i, int j) {
        return Perm( i + Perm(j));
    }
    uint Index(int i) {
        return Perm( i );
    }
    
    uint Index(double x, double y, double z) {
        return Index(to!int(x), to!int(y), to!int(z));
    }
    uint Index(double x, double y) {
        return Index(to!int(x), to!int(y));
    }
    uint Index(double x) {
        return Index(to!int(x));
    }
    
}


class PermMap(uint SIZE = 128) : ValueSource {
    double[SIZE] PRNs;
    mixin Permutation!SIZE;

    this(RandSourceUniform rsu) {
        initPermutations(rsu);
        foreach(ref p ; PRNs) {
            p = rsu.getValue(0, 0);
        }
    }
    
    double getValue(double x, double y, double z) {
        return PRNs[Index(x, y, z)];
    }
    double getValue(double x, double y) {
        return PRNs[Index(x, y)];
    }
    double getValue(double x) {
        return PRNs[Index(x)];
    }
};

class GradientNoise(string Step = "smoothStep", string Lerp = "lerp") : ValueSource {
    mixin("alias " ~ Step ~ " StepFunc;");
    mixin("alias " ~ Lerp ~ " Interpolate;");
    uint size;
    vec3d[] PRNs;
    mixin Permutation!size;
    this(uint Size, RandSourceUniform rsu) {
        size = Size;
        PRNs.length = size;
        initPermutations(rsu);
        foreach(ref p ; permutations) {
            p = rsu.get!uint(0, size);
        }

        foreach(ref p ; PRNs) {
            vec3d v;
            do {
                v = vec3d(rsu.getValue(0), rsu.getValue(0), rsu.getValue(0));
            }while(v.getLengthSQ() > 1.0);
            p = v.normalize();
            
        }
    }
    
    double getLattice(int i, int j, int k, double dx, double dy, double dz) {
        return PRNs[Index(i, j, k)].dotProduct(vec3d(dx, dy, dz));
    }

    double getLattice(int i, int j, double dx, double dy) {
        auto v = PRNs[Index(i, j)];
        return v.X * dx + v.Y * dy; // TODO: Make use of all values eventually, not only x,y but z as well. Same for 1D-version
    }

    double getLattice(int i, double dx) {
        auto v = PRNs[Index(i)];
        return v.X * dx;
    }
    
    double getValue(double x, double y, double z) {
        int i = to!int(floor(x));
        int j = to!int(floor(y));
        int k = to!int(floor(z));
        double dx = x - to!double(i);
        double dy = y - to!double(j);
        double dz = z - to!double(k);
        
        double v000 = getLattice(i  , j  , k  , dx  , dy  , dz  );
        double v100 = getLattice(i+1, j  , k  , dx-1, dy  , dz  );
        double v110 = getLattice(i+1, j+1, k  , dx-1, dy-1, dz  );
        double v010 = getLattice(i  , j+1, k  , dx  , dy-1, dz  );
        double v001 = getLattice(i  , j  , k+1, dx  , dy  , dz-1);
        double v101 = getLattice(i+1, j  , k+1, dx-1, dy  , dz-1);
        double v111 = getLattice(i+1, j+1, k+1, dx-1, dy-1, dz-1);
        double v011 = getLattice(i  , j+1, k+1, dx  , dy-1, dz-1);
        
        double wx = StepFunc(dx);
        double wy = StepFunc(dy);
        double wz = StepFunc(dz);
        
        double v00 = Interpolate(v000, v001, wz);
        double v01 = Interpolate(v010, v011, wz);
        double v11 = Interpolate(v110, v111, wz);
        double v10 = Interpolate(v100, v101, wz);
        
        double v0 = Interpolate(v00, v01, wy);
        double v1 = Interpolate(v10, v11, wy);
        
        return Interpolate(v0, v1, wx);
    }    
    double getValue(double x, double y) {
        int i = to!int(floor(x));
        int j = to!int(floor(y));
        double dx = x - to!double(i);
        double dy = y - to!double(j);
        
        double v00 = getLattice(i  , j  , dx  , dy  );
        double v10 = getLattice(i+1, j  , dx-1, dy  );
        double v11 = getLattice(i+1, j+1, dx-1, dy-1);
        double v01 = getLattice(i  , j+1, dx  , dy-1);
        
        double wx = StepFunc(dx);
        double wy = StepFunc(dy);
        
        double y0 = Interpolate(v00, v10, wx);
        double y1 = Interpolate(v01, v11, wx);
        return Interpolate(y0, y1, wy);
    }
    
    double getValue(double x) {
        int i = to!int(floor(x));
        double dx = x - to!double(i);
        
        double v00 = getLattice(i  , dx  );
        double v10 = getLattice(i+1, dx-1);
        
        double wx = StepFunc(dx);
        
        return Interpolate(v00, v10, wx);
    }
}

class GradientNoise01(string Step = "smoothStep", string Lerp = "lerp") : GradientNoise!(Step, Lerp) {
    this(uint Size, RandSourceUniform rsu) {
        super(Size, rsu);
    }
    
    override double getValue(double x, double y, double z) {
        return super.getValue(x,y,z) + 0.5;
    }    
    double getValue(double x, double y) {
        return super.getValue(x,y) + 0.5;
    }
    
    double getValue(double x) {
        return super.getValue(x) + 0.5;
    }
}

class GradientField : ValueSource {
    vec3d normal;
    double d;
    
    this(vec3d zero, vec3d one) {
        normal = one - zero;
        d = normal.dotProduct(zero);
    }
    
    double getValue(double x, double y, double z) {
        return normal.dotProduct(vec3d(x, y, z)) - d;
    }
    double getValue(double x, double y) {
        return getValue(x, y);
    }
    double getValue(double x) {
        return getValue(x);
    }    
}

class Peturber : ValueSource {
    ValueSource source;
    ValueSource petX;
    ValueSource petY;
    ValueSource petZ;
    vec3d power;
    
    this(ValueSource s, ValueSource pX = null, ValueSource pY = null, ValueSource pZ = null, vec3d p = vec3d(1,1,1)) {
        source = s;
        petX = pX;
        petY = pY;
        petZ = pZ;
        power = p;
    }
    
    double getValue(double x, double y, double z) {
        if (petX !is null) {
            x += petX.getValue(x, y, z) * power.X;
        }
        if (petY !is null) {
            y += petY.getValue(x, y, z) * power.Y;
        }
        if (petZ !is null) {
            z += petZ.getValue(x, y, z) * power.Z;
        }
        return source.getValue(x, y, z);
    }
    double getValue(double x, double y) {
        if (petX !is null) {
            x += petX.getValue(x, y) * power.X;
        }
        if (petY !is null) {
            y += petY.getValue(x, y) * power.Y;
        }
        return source.getValue(x, y);
    }
    double getValue(double x) {
        if (petX !is null) {
            x += petX.getValue(x) * power.X;
        }
        return source.getValue(x);
    }    
}

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


Type CatmullRomSpline(Type)(double t, Type[] ar ...)
in{
    enforce(ar.length >= 4, "Can't do catmull-rom with less than 4 control points!");
}
body{
    
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
    auto c1 = -0.5 * knot[0] +  0.0 * knot[1] +  0.5 * knot[2] +  0.0 * knot[3];
    auto c0 =  0.0 * knot[0] +  1.0 * knot[1] +  0.0 * knot[2] +  0.0 * knot[3];
    
    return ((c3*x + c2)*x + c1)*x + c0;
}

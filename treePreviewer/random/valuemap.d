module random.valuemap;

import std.conv;
import std.algorithm;
import std.stdio;
import std.string;

import util.util;
import util.math;
import random.random;
import graphics.image;

alias ValueMap2D!double ValueMap2Dd;

class ValueMap2D(StorageType, bool Wrap = true) : ValueSource {
    
    StorageType[] randMap;
    uint sizeX, sizeY;

    this() {
    }
    
    this(uint sizeX, uint sizeY) {
            alloc(sizeX, sizeY);
    }

    void alloc(uint _sizeX, uint _sizeY) {
        sizeX = _sizeX;
        sizeY = _sizeY;
        auto mul = sizeX * sizeY;
        randMap.length = mul;
    }

    //Gets values 0.._sizeX, 0.._sizeY from source and puts in place.
    void fill(Source)(Source source, uint _sizeX, uint _sizeY) {
        sizeX = _sizeX;
        sizeY = _sizeY;
        auto mul = sizeX * sizeY;
        randMap.length = mul;
        foreach(i ; 0 .. mul) {
            //Since not specified or anything, sample at +½, +½ to avoid sampling at lattice points (perlin)
            randMap[i] = random.random.getValue(source, to!double(i % sizeX)+0.5, to!double(i / sizeX)+0.5);
        }
    }

    //Takes x*y samples in designated area.
    void fill(Source)(Source source, uint _sizeX, uint _sizeY, double minX, double minY, double maxX, double maxY) {
        sizeX = _sizeX;
        sizeY = _sizeY;
        auto mul = sizeX * sizeY;
        auto deltaX = (maxX - minX) / to!double(sizeX);
        auto deltaY = (maxY - minY) / to!double(sizeY);
        randMap.length = mul;
        foreach(i ; 0 .. mul) {
            randMap[i] = random.random.getValue(source, minX + to!double(i % sizeX) * deltaX, to!double(i / sizeX) * deltaY);
        }
    }

    void normalize(const double Min, const double Max) {
        double min = double.max;
        double max = -double.max;
        foreach(val; randMap) {
            min = std.algorithm.min(min, val);
            max = std.algorithm.max(max, val);
        }
        double scale = (Max-Min) / (max-min);
        writeln(text("normalize: min ", min, " max ", max));

        foreach(ref val; randMap) {
            val = (val-min) * scale + Min;
        }
    }

    
    StorageType getValue(double x, double y, double z) { return 0; }
    StorageType getValue(double x) { return 0; }
    StorageType getValue(double x, double y) {
                //writeln(text(x, " ", y));
        static if(Wrap) {
            x = posMod(to!int(x), sizeX);
            y = posMod(to!int(y), sizeY);
        }
        return randMap[to!uint(y) * sizeX + to!uint(x)];
    }

    void set(int x, int y, StorageType value) {
        randMap[x + y * sizeX] = value;
    }
    StorageType get(int x, int y) {
        debug{
            BREAK_IF(x < 0 || x >= sizeX || y < 0 || y >= sizeY);
        }
        return randMap[x + y * sizeX];
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

    void saveBin(string filename) {
        std.file.write(filename, randMap);
    }
    void loadBin(string filename) {
        randMap = cast(StorageType[])std.file.read(filename);
        std.file.write(filename, randMap);
    }
};

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



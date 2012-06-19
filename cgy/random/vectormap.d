module random.vectormap;

import std.conv;
import std.algorithm;
import std.stdio;
import std.string;

import util.util;
import util.math;
import random.random;
import graphics.image;


final class Vector2DMap2D(T, bool Wrap = true) {

    alias Vector2d!T StorageType;
    StorageType[] map;
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
        map.length = mul;
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

    //Normalizes based on length of vectors. Vectors of length 0 get to point in the 0,1-direction.
    void normalize(const T Min, const T Max) {
        double min = double.max;
        double max = 0;
        foreach(ref val; map) {
            auto t = val.getLengthSQ();
            if(t == 0) {
                val.set(0,1);
                t = 1;
            }
            min = std.algorithm.min(min, t);
            max = std.algorithm.max(max, t);
        }
        min = sqrt(min);
        max = sqrt(max);
        double scale = (Max-Min) / (max-min);
        writeln(text("normalize: min ", min, " max ", max));

        foreach(ref val; randMap) {
            val = (val-min) * scale + Min;
        }
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


    Image toImage(T min, T max, bool doClamp = true, double[4] delegate(double) color = null) {
        ubyte[] imgData;
        imgData.length = 4 * sizeX * sizeY;
        ubyte* ptr = imgData.ptr;
        auto range = max - min;
        foreach(value ; map) {
            double V = cast(double)(value-min) / cast(double)range;
            if (color is null ) {
                if(doClamp) {
                    V = clamp(V, 0, 1);
                }
                ptr[0..3] = to!ubyte(255 * V);
            } else {
                auto v = color(V);
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

    void saveAsImage(string imgName, T min, T max, bool clamp = true) {
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

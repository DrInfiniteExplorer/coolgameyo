module random.valuemap;

import std.conv;
import std.algorithm;
import std.stdio;
import std.string;

import cgy.math.math : posModV;
import cgy.util.filesystem;
import random.random;
import random.valuesource;
import graphics.image;

import cgy.math.vector : vec2i;

alias ValueMap2D!double ValueMap2Dd;

final class ValueMap2D(StorageType, bool Wrap = true) : ValueSource {
    
    StorageType[] data;
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
        data.length = mul;
    }

    //Gets values 0.._sizeX, 0.._sizeY from source and puts in place.
    void fill(Source)(Source get, uint _sizeX, uint _sizeY) {
        sizeX = _sizeX;
        sizeY = _sizeY;
        auto mul = sizeX * sizeY;
        data.length = mul;
        foreach(i ; 0 .. mul) {
            auto pos = vec2d(cast(double)(i % sizeX), cast(double)(i / sizeX));
            data[i] = get( pos );
        }
    }

    void foreachDo(Source, string Op)(Source source, uint _sizeX, uint _sizeY) {
        sizeX = _sizeX;
        sizeY = _sizeY;
        auto mul = sizeX * sizeY;
        data.length = mul;
        foreach(i ; 0 .. mul) {
            mixin(q{ data[i] } ~ Op ~ q{ random.random.getValue(source, cast(double)(i % sizeX), cast(double)(i / sizeX));});
        }
    }

    //Takes x*y samples in designated area.
    void fill(Source)(Source source, uint _sizeX, uint _sizeY, double minX, double minY, double maxX, double maxY) {
        sizeX = _sizeX;
        sizeY = _sizeY;
        auto mul = sizeX * sizeY;
        auto deltaX = (maxX - minX) / to!double(sizeX);
        auto deltaY = (maxY - minY) / to!double(sizeY);
        data.length = mul;
        foreach(i ; 0 .. mul) {
            data[i] = random.random.getValue(source, minX + to!double(i % sizeX) * deltaX, to!double(i / sizeX) * deltaY);
        }
    }

    void normalize(const double Min, const double Max) {
        double min = double.max;
        double max = -double.max;
        foreach(val; data) {
            min = std.algorithm.min(min, val);
            max = std.algorithm.max(max, val);
        }
        double scale = (Max-Min) / (max-min);
        writeln(text("normalize: min ", min, " max ", max));

        foreach(ref val; data) {
            val = (val-min) * scale + Min;
        }
    }

    
    override StorageType getValue3(vec3d pos) { return 0; }
    override StorageType getValue(double x) { return 0; }
    override StorageType getValue2(vec2d pos) {
                //writeln(text(x, " ", y));
        static if(Wrap) {
            pos = posModV(pos, vec2i(sizeX, sizeY));
        }
        return data[cast(uint)pos.y * sizeX + cast(uint)pos.x];
    }

    void set(int x, int y, StorageType value) {
        debug{
            BREAK_IF(x < 0 || x >= sizeX || y < 0 || y >= sizeY);
        }
        data[x + y * sizeX] = value;
    }
    StorageType get(int x, int y) {
        debug{
            BREAK_IF(x < 0 || x >= sizeX || y < 0 || y >= sizeY);
        }
        return data[x + y * sizeX];
    }

    
    Image toImage(StorageType min, StorageType max, bool doClamp = true, double[4] delegate(double) color = null) {
        ubyte[] imgData;
        imgData.length = 4 * sizeX * sizeY;
        ubyte* ptr = imgData.ptr;
        auto range = max - min;
        foreach(value ; data) {
            value = (value-min) / range;
            if (color is null ) {
                if(doClamp) {
                    value = clamp(value, 0.0, 1.0);
                }
                ptr[0..3] = cast(ubyte)(255 * value);
            } else {
                auto v = color(value);
                if(doClamp) {
                    foreach(ref vv; v) {
                        vv = clamp(vv, 0.0, 1.0);
                    }
                }
                ptr[0] = cast(ubyte)(255 * v[0]);
                ptr[1] = cast(ubyte)(255 * v[1]);
                ptr[2] = cast(ubyte)(255 * v[2]);
                ptr[3] = cast(ubyte)(255 * v[3]);
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

    //Note! Does not save the dimensions!
    void saveBin(string filename) {
        //std.file.write(filename, data);
        writeBin(filename, data);
    }
    void loadBin(string filename) {
        //data = cast(StorageType[])std.file.read(filename);
        readBin(filename, data);
    }
};

Image toImage(ValueSource source, double lx, double ly, double hx, double hy, uint px, uint py, double low, double high,
              double[4] delegate(double) color = null){
    ValueMap2Dd map = new ValueMap2Dd();
    auto rx = (hx - lx) / to!double(px);
    auto ry = (hy - ly) / to!double(py);
    map.fill((vec2d pos)
             {
                 auto xx = lx + rx * pos.x;
                 auto yy = ly + ry * pos.y;
                 return source.getValue2(vec2d(xx, yy));
             }
             , px, py);
    return map.toImage(low, high, true, color);
}



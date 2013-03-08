module random.vectormap;

import std.algorithm;
import std.conv;
import std.exception;
import std.math;
import std.stdio;
import std.string;

import math.vector;

import util.util;
import util.filesystem;
import util.math;
import random.random;
import random.xinterpolate;
import graphics.image;


final class Vector2DMap2D(T, bool Wrap = true) {

    alias vector2!T StorageType;
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
        foreachDo!(Source, "=")(source, _sizeX, _sizeY);
    }
    void foreachDo(Source, string Op)(Source source, uint _sizeX, uint _sizeY) {
        sizeX = _sizeX;
        sizeY = _sizeY;
        auto mul = sizeX * sizeY;
        map.length = mul;
        foreach(i ; 0 .. mul) {
            mixin(q{ map[i] } ~ Op ~ q{ random.random.getValue(source, cast(double)(i % sizeX), cast(double)(i / sizeX));});
        }
    }

    //Takes x*y samples in designated area.
    void fill(Source)(Source source, uint _sizeX, uint _sizeY, double minX, double minY, double maxX, double maxY) {
        sizeX = _sizeX;
        sizeY = _sizeY;
        auto mul = sizeX * sizeY;
        auto deltaX = (maxX - minX) / cast(double)sizeX;
        auto deltaY = (maxY - minY) / cast(double)sizeY;
        data.length = mul;
        foreach(i ; 0 .. mul) {
            data[i] = random.random.getValue(source, minX + cast(double)(i % sizeX) * deltaX, cast(double)(i / sizeX) * deltaY);
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

        foreach(ref val; map) {
            val = (val-min) * scale + Min;
        }
    }


    void set(int x, int y, StorageType value) {
        static if(Wrap) {
            x = x % sizeX;
            y = y % sizeY;
        } else {
            debug{
                BREAK_IF(x < 0 || x >= sizeX || y < 0 || y >= sizeY);
            }
        }
        map[x + y * sizeX] = value;
    }

    StorageType getValue(int x, int y) {
        return get(x, y);
    }
    StorageType get(int x, int y) {
        static if(Wrap) {
            x = x % sizeX;
            y = y % sizeY;
        } else {
            debug{
                BREAK_IF(x < 0 || x >= sizeX || y < 0 || y >= sizeY);
            }
        }
        return map[x + y * sizeX];
    }


    Image toImage(T min, T max, bool doClamp = true, double[4] delegate(double) color = null) {
        ubyte[] imgData;
        imgData.length = 4 * sizeX * sizeY;
        ubyte* ptr = imgData.ptr;
        auto range = max - min;
        foreach(value ; map) {
            double V = cast(double)(value.getLength()-min) / cast(double)range;
            if (color is null ) {
                if(doClamp) {
                    V = clamp(V, 0.0, 1.0);
                }
                ptr[0..3] = cast(ubyte)(255 * V);
            } else {
                auto v = color(V);
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
        int spacing = 50;
        double arrowSize = 20;
        for(int y = 5 ; y < sizeY ; y += spacing) {
            for(int x = 5 ; x < sizeX ; x += spacing) {
                auto v = get(x, y);
                auto len = (v.getLength() - min) / range;
                len *= arrowSize;
                v.normalizeThis();
                auto v_cross = vec2d(-v.y, v.x);

                auto center = vec2d(x, y);
                auto start = center - v * len;
                auto end = center + v * len;
                img.drawLine(start.convert!int, end.convert!int, vec3i(0, 255, 0));
                auto start_a = start + v_cross * len*0.3;
                auto start_b = start - v_cross * len*0.3;
                img.drawLine(start_a.convert!int, start_b.convert!int, vec3i(0, 0, 0));

            }
        }
        return img;        
    }

    void saveAsImage(string imgName, T min, T max, bool clamp = true) {
        auto img = toImage(min, max, clamp);
        img.save(imgName);
    }

    void saveBin(string filename) {
        //std.file.write(filename, map);
        writeBin(filename, map);
    }
    void loadBin(string filename) {
        //map = cast(StorageType[])std.file.read(filename);
        readBin(filename, map);
    }


    float getTimeStep() const {
        return 1.0f;
    }

    // Real simple shit.
    void advectValueField(MapType)(MapType inMap, MapType outMap) {
        enforce(inMap.sizeX == sizeX, "Can't advect maps of different X-sizes");
        enforce(inMap.sizeY == sizeY, "Can't advect maps of different Y-sizes");
        enforce(inMap.sizeX == outMap.sizeX, "Can't advect maps of different X-sizes");
        enforce(inMap.sizeY == outMap.sizeY, "Can't advect maps of different Y-sizes");

        foreach(y ; 0 .. sizeY) {
            foreach(x ; 0 .. sizeX) {
                auto where = StorageType(x, y);
                auto dir = get(x, y);
                auto grad = inMap.upwindGradient(x, y, dir.x, dir.y, 1.0);
                outMap.set(x, y, -dir.dotProduct(grad));
            }
        }
    }


    //Doesn't work well when there are areas with no "wind", since we walk backwards to find
    //a value to put "here".
    void advectVectorField(MapType)(MapType inMap, MapType outMap, float t, int steps = 3) {
        enforce(inMap.sizeX == sizeX, "Can't advect maps of different X-sizes");
        enforce(inMap.sizeY == sizeY, "Can't advect maps of different Y-sizes");
        enforce(inMap.sizeX == outMap.sizeX, "Can't advect maps of different X-sizes");
        enforce(inMap.sizeY == outMap.sizeY, "Can't advect maps of different Y-sizes");

        auto maxTimeStep = getTimeStep();
        auto dt = t / steps;

        foreach(y ; 0 .. sizeY) {
            foreach(x ; 0 .. sizeX) {
                auto where = StorageType(x, y);
                foreach(step ; 0 .. steps) {
                    
                    where = where - XInterpolate!lerp(this, where.x, where.y) * dt;
                }
                auto value = XInterpolate!lerp(this, where.x, where.y);
                outMap.set(x, y, value);
            }
        }
    }




};

module worldgen.heightmap;

import std.algorithm : swap, min, max, reduce;
import std.array : array;
import std.parallelism;
import std.mmfile;
import std.math;
import std.random;
import std.typecons;

import derelict.sdl.sdl;

import graphics.camera;
import graphics.heightmap;
alias graphics.heightmap.Heightmap HMap;

import math.math : equals;
import math.math : advect, clamp, fastFloor;
import random.random : BSpline;
import random.simplex;
import random.xinterpolate4 : XInterpolate24;
import util.filesystem;
import util.pos;
import util.util;
import worldgen.gpuerosion;
import worldgen.maps;
import worldgen.strata;

enum SampleIntervall = 25; //10 meters between each sample

immutable maxHeight = 10_000;
immutable startAmplitude = maxHeight / 2;
immutable startIntervall = 60000;
immutable endIntervall = SampleIntervall * 3;
immutable baseFrequency = 1.0f / startIntervall;
int octaves;
float endAmplitude;

immutable InitSoilDepth = 0.0;

immutable Ridged = true;

int IterModValue;

shared static this() {
    octaves = cast(int)logb(startIntervall / endIntervall);
    endAmplitude = startAmplitude * (0.5 ^^ octaves);

    //1 -> Always
    //2 -> every x'nthd
    //>= octaves -> first only.
    IterModValue = 3;
}


class HeightMaps {
    size_t worldSize; //In meters
    size_t mapSize; //In samples
    size_t mapSizeSQ;
    size_t mapSizeBytes;
    WorldMap worldMap;

    MmFile heightmapFile;
    float[] mapData; // Pointer to memory in heightmapfile.
    MmFile soilFile;
    float[] soilData;
    MmFile waterFile;
    float[] waterData;

    SimplexNoise baseHeightNoise;

    this(WorldMap _worldMap) {
        worldMap = _worldMap;
        auto size = .worldSize; // 1 mil
        worldSize = size; // In meters woah.
        mapSize = worldSize / SampleIntervall;
        mapSizeSQ = mapSize ^^ 2;
        mapSizeBytes = mapSize * mapSize * float.sizeof;
        msg("mapSize(kilo)Bytes: ", mapSizeBytes / 1024);
    }

    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }
    void destroy() {
        destroyed = true;
        delete heightmapFile;
        delete soilFile;
        delete waterFile;
        mapData = null;
        soilData = null;
        waterData = null;
    }

    void load(int seed) {
        auto heightPath = worldMap.worldPath ~ "/map1";
        msg("Loading heightmap at: ", heightPath);
        heightmapFile = new MmFile(heightPath, MmFile.Mode.readWrite, mapSizeBytes, null, 0);
        mapData = cast(float[])heightmapFile[];

        auto soilPath = worldMap.worldPath ~ "/map2";
        soilFile = new MmFile(soilPath, MmFile.Mode.readWrite, mapSizeBytes, null, 0);
        soilData = cast(float[])soilFile[];

        auto waterPath = worldMap.worldPath ~ "/map3";
        waterFile = new MmFile(waterPath, MmFile.Mode.readWrite, mapSizeBytes, null, 0);
        waterData = cast(float[])waterFile[];

        baseHeightNoise = new SimplexNoise(seed);
    }

    float getOriginalHeight(vec2i _pos) {
        float value = 0;
        vec2f pos = _pos.convert!float;
        pos *= baseFrequency;
        pos += vec2f(3.435123, 4.41231);

        float amplitude = startAmplitude;

        for(int iter = 0; iter < octaves; iter++) {
            if(iter % IterModValue == 0) {
                static if(Ridged) {
                    value += amplitude * (1 - abs(baseHeightNoise.getValue2(pos.convert!double)));
                } else {
                    value += amplitude * ( abs(baseHeightNoise.getValue2(pos.convert!double)));
                }
            } else {
                value += amplitude * baseHeightNoise.getValue2(pos.convert!double);
            }
            amplitude *= 0.5;
            pos *= 2;
        }

        auto dst = _pos.convert!float.getDistance(vec2f(mapSize * 0.5 * SampleIntervall));
        dst /= (mapSize*0.25 * SampleIntervall);
        //msg(dst);

        return value;
        //return dst < 1 ? 100 : 0;
        //return dst < 1 ? sqrt(1-dst^^2)*100 : 0;
        //return dst < 1 ? (1-dst)*100 : 0;
    }

    float getOriginalSoil(vec2i _pos) {
        float value = 0;
        vec2f pos = _pos.convert!float;
        float baseFrequency = 1.0 / (SampleIntervall * 10);
        pos *= baseFrequency;
        pos += vec2f(-2.435123, 7.41231);

        float amplitude = 50;

        for(int iter = 0; iter < 2; iter++) {
            value += amplitude * baseHeightNoise.getValue2(pos.convert!double);
            amplitude *= 0.5;
            pos *= 2;
        }
        return max(0, value);
    }

    void generate(int seed) {
        baseHeightNoise = new SimplexNoise(seed);

        auto heightPath = worldMap.worldPath ~ "/map1";
        msg("Creating heightmap at: ", heightPath);
        BREAK_IF(heightmapFile !is null);
        heightmapFile = new MmFile(heightPath, MmFile.Mode.readWriteNew, mapSizeBytes, null, 0);
        mapData = cast(float[])heightmapFile[];

        auto soilPath = worldMap.worldPath ~ "/map2";
        soilFile = new MmFile(soilPath, MmFile.Mode.readWrite, mapSizeBytes, null, 0);
        soilData = cast(float[])soilFile[];

        size_t LIMIT_STEP = mapSizeSQ / 2500;
        size_t progress = 0;
        foreach(size_t i, ref value ; mapData) {
                if( (i % LIMIT_STEP) == 0) {
                progress += LIMIT_STEP;
                msg("Progress: ", 100.0f * cast(float)progress / mapSizeSQ);
            }
            auto pos = vec2i(cast(int)(i % mapSize), cast(int)(i / mapSize));
            value = getOriginalHeight(pos*SampleIntervall);
        }

        msg("h max", reduce!max(mapData));
        msg("h min", reduce!min(mapData));
        msg("h mean", reduce!"a+b"(mapData) / mapSizeSQ);
        mapData[] -= reduce!"a+b"(mapData) / mapSizeSQ;

        applyErosion(seed);
    }

    void addSoil(GPUErosion ero) {
        ero.getSoil(soilData);
        size_t LIMIT_STEP = mapSizeSQ / 2500;
        size_t progress = 0;
        foreach(size_t i, ref value ; soilData) {
            if( (i % LIMIT_STEP) == 0) {
                progress += LIMIT_STEP;
                msg("Progress: ", 100.0f * cast(float)progress / mapSizeSQ);
            }
            auto pos = vec2i(cast(int)(i % mapSize), cast(int)(i / mapSize));
            value += getOriginalSoil(pos*SampleIntervall);
        }
        ero.setSoil(soilData);
    }



    void applyErosion(int seed) {

        auto getMaterialConstants(int x, int y, int z) {
            int materialNum = worldMap.getStrataNum(x, y, z);
            auto material = worldMap.materials[materialNum];

            return tuple(material.dissolutionConstant, material.talusConstant);
        }

        auto ero = new GPUErosion();
        soilData[] = InitSoilDepth; // 2 meters worth of soil to begin with.
        ero.init(mapData, soilData, mapSize, mapSize, seed);

        HMap height = new HMap;
        HMap wtr = new HMap;
        ero.heightMap = height;
        //ero.waterMap = wtr;
        height.depth = wtr.depth = mapSize * SampleIntervall;
        height.width = wtr.width = mapSize * SampleIntervall;
        // ERODE ERODE ERODE

        // Start erosion thread.
        bool done = false;
        Camera camera = new Camera;
        camera.speed *= 7;
        camera.farPlane *= 25;
        camera.setPosition(vec3d(0, 0, 20));
        camera.setTargetDir(vec3d(0.7, 0.7, 0));
        int c = 0;
        immutable limit = 5750;
        renderLoop(camera, 
                   { return c > limit; },
                   {
                       /*
                       synchronized(wtr) {
                           import derelict.opengl.gl;
                           
                           glEnable( GL_POLYGON_OFFSET_FILL );      
                           glPolygonOffset( 1f, 1f );

                           wtr.alpha = 1.0;
                           //glEnable(GL_BLEND);
                           //glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
                           
                           wtr.render(camera);
                           //glDisable(GL_BLEND);
                           glDisable( GL_POLYGON_OFFSET_FILL );      
                       }
                       */
                       synchronized(height) {
                           height.render(camera);
                       }
                       /+
                       if(c == 0) {
                           addSoil(ero);
                           rainRate = 0.0012;
                           depositToSoil = 1;
                           transportSoil = 1;
                           ero.rain();
                       } else {
                           ero.erode();
                       }+/

                       
                       if(c == 0) {
                           depositToSoil = 0;
                           transportSoil = 0;
                           rainRate = 1000;
                           ero.rain();
                       } else {
                           ero.erode();
                       }
                       if(c == 5000) {
                           addSoil(ero);
                           rainRate = 10;
                           depositToSoil = 1;
                           transportSoil = 1;
                           talusLimit = 0.7 * SampleIntervall;
                           ero.rain();
                       }
                       if(c > 5000) {
                           rainRate = 0.012;
                           ero.rain();
                       }

                       

                       /*
                       if(c == 1_000) {
                           addSoil(ero);
                           rainRate = 0.0012;
                       } else if(c < 11_000) {
                           ero.erode();
                       }
                       */
                       c++;
                   });
        ero.getHeight(mapData);
        ero.getSoil(soilData);
        ero.getWater(waterData);
    }

    ref float getMapValue(string which, bool clamp)(int x, int y) {
        static if(clamp) {
            x = .clamp(x, 0, mapSize-1);
            y = .clamp(y, 0, mapSize-1);
        } else {
            BREAK_IF(x < 0);
            BREAK_IF(y < 0);
            BREAK_IF(x >= mapSize);
            BREAK_IF(y >= mapSize);
        }
        auto idx = y * mapSize + x;
        return mixin(which)[idx];
    }

    alias getMapValue!("mapData",false) getHeightValue;
    alias getMapValue!("soilData", false) getSoilValue;

    float getMap(string which, bool interpolate = true)(TileXYPos pos) {
        vec2f pt = pos.value.convert!float / cast(float)SampleIntervall;
        auto get = &getMapValue!(which, true);
        static if(interpolate) {
            import random.xinterpolate;
            import random.random;
            //*
            return XInterpolate2!(SmootherInter, get)(pt);
            /*/
            return XInterpolate24!(BSpline, get)(pt);
            //*/
        } else {
            return get(cast(int)pt.x, cast(int)pt.y);
        }
    }

    auto getHeight(bool interpolate = true)(TileXYPos pt) {
        return getMap!("mapData", interpolate)(pt);
    }
    auto getSoil(bool interpolate = true)(TileXYPos pt) {
        return getMap!("soilData", interpolate)(pt);
    }
}


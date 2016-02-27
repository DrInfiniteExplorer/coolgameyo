module worldgen.heightmap;

import std.algorithm : swap, min, max, reduce;
import std.array : array;
import std.parallelism;
import std.mmfile;
import std.math;
import std.random;
import std.typecons;

import derelict.sdl2.sdl;

import graphics.camera;
import graphics.heightmap;
alias graphics.heightmap.Heightmap HMap;

import json;

import math.math : equals;
import math.math : advect, fastFloor;
import random.random : BSpline;
import random.simplex;
import random.xinterpolate4 : XInterpolate24;
import util.filesystem;
import util.pos;
import util.util;
import cgy.erosion.gpu;
import worldgen.maps;
import worldgen.strata;

immutable maxHeight = 10_000;
immutable startAmplitude = maxHeight / 2;
immutable startIntervall = 60000;
immutable endIntervall = SampleIntervall * 3;
immutable baseFrequency = 1.0f / startIntervall;

__gshared int octaves;
__gshared float endAmplitude;

immutable InitSoilDepth = 0;

immutable Ridged = true;

__gshared int IterModValue;

shared static this() {
    octaves = cast(int)logb(startIntervall / endIntervall);
    //octaves = 4;
    msg("octaves: ", octaves);
    endAmplitude = startAmplitude * (0.5 ^^ octaves);

    //1 -> Always
    //2 -> every x'nthd
    //>= octaves -> first only.
    IterModValue = 3;
}


class HeightMaps {
    size_t WorldSize; //In meters
    size_t mapSize; //In samples
    size_t mapSizeSQ;
    size_t mapSizeBytes;
    WorldMap worldMap;

    MmFile heightmapFile;
    short[] heightData; // Pointer to memory in heightmapfile.
    MmFile originalHeightmapFile;
    short[] originalHeightData; // Pointer to memory in heightmapfile.
    MmFile soilFile;
    short[] soilData;
    MmFile waterFile;
    short[] waterData;
    MmFile flowFile;
    vec2f[] flowData;

    SimplexNoise baseHeightNoise;

    this(WorldMap _worldMap) {
        worldMap = _worldMap;
        auto size = .WorldSize; // 1 mil
        WorldSize = size; // In meters woah.
        mapSize = WorldSize / SampleIntervall;
        mapSizeSQ = mapSize ^^ 2;
        mapSizeBytes = mapSize * mapSize * short.sizeof;
        msg("mapSize(kilo)Bytes: ", mapSizeBytes / 1024);
    }

    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }
    void destroy() {
        destroyed = true;
        delete heightmapFile;
        delete originalHeightmapFile;
        delete soilFile;
        delete waterFile;
        delete flowFile;
        heightData = null;
        originalHeightData = null;
        soilData = null;
        waterData = null;
        flowData = null;
    }

    void loadFiles(bool create) {
        auto mode = create ? MmFile.Mode.readWriteNew : MmFile.Mode.readWrite;
        auto heightPath = worldMap.worldPath ~ "/map1";
        heightmapFile = new MmFile(heightPath, mode, mapSizeBytes, null, 0);
        heightData = cast(short[])heightmapFile[];

        auto soilPath = worldMap.worldPath ~ "/map2";
        soilFile = new MmFile(soilPath, mode, mapSizeBytes, null, 0);
        soilData = cast(short[])soilFile[];

        auto waterPath = worldMap.worldPath ~ "/map3";
        waterFile = new MmFile(waterPath, mode, mapSizeBytes, null, 0);
        waterData = cast(short[])waterFile[];

        auto flowPath = worldMap.worldPath ~ "/map4";
        flowFile = new MmFile(flowPath, mode, 4 * mapSizeBytes, null, 0);
        flowData = cast(vec2f[])flowFile[];

        auto originalHeightPath = worldMap.worldPath ~ "/map5";
        originalHeightmapFile = new MmFile(originalHeightPath, mode, mapSizeBytes, null, 0);
        originalHeightData = cast(short[])originalHeightmapFile[];
    }

    void load(int seed) {
        loadFiles(false);
        baseHeightNoise = new SimplexNoise(seed);
    }

    void generateOriginalHeightmap() {

        short getVal(vec2i _pos) {
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

            return cast(short)value;
        }

        size_t LIMIT_STEP = mapSizeSQ / 2500;
        size_t progress = 0;
        foreach(size_t i, ref value ; heightData) {
            if( (i % LIMIT_STEP) == 0) {
                progress += LIMIT_STEP;
                msg("Progress: ", 100.0f * cast(float)progress / mapSizeSQ);
            }
            auto pos = vec2i(cast(int)(i % mapSize), cast(int)(i / mapSize));
            value = cast(short)getVal(pos*SampleIntervall);
        }
        float[] tmp;
        tmp.length = heightData.length;
        tmp.convertArray(heightData);
        msg("h max", reduce!max(tmp));
        msg("h min", reduce!min(tmp));
        auto mean = reduce!"a+b"(tmp) / mapSizeSQ;
        msg("h mean", mean);
        heightData[] -= cast(short)mean;
        originalHeightData[] = heightData[];
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

        auto erodedPath = worldMap.worldPath ~ "/eroded";
        if(exists(erodedPath)) {
            loadFiles(false);
            return;
        } else {
            loadFiles(true);
        }

        generateOriginalHeightmap();

        applyErosion(seed);
        writeText(erodedPath, "");
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
            value += cast(short)getOriginalSoil(pos*SampleIntervall);
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
        ero.init(heightData, soilData, mapSize, mapSize, seed);

        HMap height = new HMap;
        scope(exit) {
            height.destroy();
        }
        height.depth = mapSize * SampleIntervall;
        height.width = mapSize * SampleIntervall;
        // ERODE ERODE ERODE

        // Start erosion thread.
        bool done = false;
        Camera camera = new Camera;
        camera.speed *= 7;
        camera.farPlane *= 25;
        camera.setPosition(vec3d(WorldSize / 3.0, -(WorldSize / 5.0), WorldSize / 3.0));
        camera.setTargetDir(vec3d(0.1, 0.7, -0.4));
        //camera.mouseMoveEnabled = false;
        int c = 0;
        immutable limit = 5750;
        renderLoop(camera, 
                   { return c > limit; },
                   {

                       synchronized(height) {
                           height.render(camera);
                       }
                       
                       if(c == 0) {
                           depositToSoil = 0;
                           transportSoil = 0;
                           rainRate = 1000;
                           ero.rain();
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
                       if(c < 5750) {
                           ero.erode();
                           synchronized(height) {
                               //heightMap.load(hm);
                               uint[4] tex;
                               tex[0] = ero.height;
                               tex[1] = ero.soil;
                               tex[2] = ero.water;
                               tex[3] = ero.sediment;
                               height.loadTexture(tex, cast(int)mapSize, cast(int)mapSize);
                               height.setColor(vec3f(0.4, 0.7, 0.3));
                           }
                           //if(waterMap) {
                           //    synchronized(waterMap) {
                           //        uint[3] tex;
                           //        tex[0] = height;
                           //        tex[1] = soil;
                           //        tex[2] = water;
                           //        waterMap.loadTexture(tex, cast(int)mapSize, cast(int)mapSize);
                           //        waterMap.setColor(vec3f(0.0, 0.0, 0.4));
                           //    }
                           //}


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
        ero.getHeight(heightData);
        ero.getSoil(soilData);
        ero.getWater(waterData);
        ero.getFlow(flowData);
        ero.destroy();
    }

    float getMapValue(string which, bool clamp)(int x, int y) {
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
        return cast(float)mixin(which)[idx];
    }

    alias getMapValue!("heightData",true) getHeightValueClamp;
    alias getMapValue!("soilData",true) getSoilValueClamp;
    alias getMapValue!("waterData",true) getWaterValueClamp;
    alias getMapValue!("heightData",false) getHeightValue;
    alias getMapValue!("soilData", false) getSoilValue;
    alias getMapValue!("waterData", false) getWaterValue;

    float getMap(string which, bool interpolate = true)(TileXYPos pos) {
        vec2f pt = pos.value.convert!float / cast(float)SampleIntervall;
        auto get = &getMapValue!(which, true);
        static if(interpolate) {
            import random.xinterpolate;
            import random.random;
            /*
            return XInterpolate2!(SmootherInter, get)(pt); // Produces bad looking terrain
            /*/
            //return XInterpolate24!(BSpline, get)(pt);
            return XInterpolate24!(CubicInter, get)(pt);
            //*/
        } else {
            return get(cast(int)pt.x, cast(int)pt.y);
        }
    }

    // Used to calculate village score
    vec2f getSampleSlope(vec2i samplePos) {
        int x = samplePos.x;
        int y = samplePos.y;
        float getHeight(int x, int y) {
            return getHeightValueClamp(x, y) + getSoilValueClamp(x, y);
        }
        float slopeX = getHeight(x - 1, y) - getHeight(x + 1, y);
        float slopeY = getHeight(x, y - 1) - getHeight(x, y + 1);
        immutable float mult = 1.0 / ( 2.0 * SampleIntervall);
        return vec2f(slopeX, slopeY) * mult;
    }

    auto getOriginalHeight(bool interpolate = true)(TileXYPos pt) {
        return getMap!("originalHeightData", interpolate)(pt);
    }
    auto getHeight(bool interpolate = true)(TileXYPos pt) {
        return getMap!("heightData", interpolate)(pt);
    }
    auto getSoil(bool interpolate = true)(TileXYPos pt) {
        return getMap!("soilData", interpolate)(pt);
    }
    auto getWater(bool interpolate = true)(TileXYPos pt) {
        return getMap!("waterData", interpolate)(pt);
    }
}


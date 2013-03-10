module worldgen.heightmap;

import std.algorithm : swap;
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
import random.xinterpolate4 : XInterpolate24;
import util.filesystem;
import util.pos;
import util.util;
import worldgen.erosion;
import worldgen.maps;
import worldgen.strata;

enum sampleIntervall = 10; //10 meters between each sample

class HeightMaps {
    int worldSize; //In meters
    int mapSize; //In samples
    int mapSizeSQ;
    uint mapSizeBytes;
    WorldMap worldMap;

    MmFile heightmapFile;
    float[] mapData; // Pointer to memory in heightmapfile.
    MmFile soilFile;
    float[] soilData; // Pointer to memory in heightmapfile.

    this(WorldMap _worldMap) {
        worldMap = _worldMap;
        auto size = .worldSize; // 1 mil
        worldSize = size; // In meters woah.
        mapSize = worldSize / sampleIntervall;
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
        mapData = null;
        soilData = null;
    }

    void load() {
        auto heightPath = worldMap.worldPath ~ "/map1";
        msg("Loading heightmap at: ", heightPath);
        heightmapFile = new MmFile(heightPath, MmFile.Mode.readWrite, mapSizeBytes, null, 0);
        mapData = cast(float[])heightmapFile[];

        auto soilPath = worldMap.worldPath ~ "/map2";
        soilFile = new MmFile(soilPath, MmFile.Mode.readWrite, mapSizeBytes, null, 0);
        soilData = cast(float[])soilFile[];
    }

    void generate(int seed) {

        auto heightPath = worldMap.worldPath ~ "/map1";
        msg("Creating heightmap at: ", heightPath);
        BREAK_IF(heightmapFile !is null);
        heightmapFile = new MmFile(heightPath, MmFile.Mode.readWriteNew, mapSizeBytes, null, 0);
        mapData = cast(float[])heightmapFile[];

        auto soilPath = worldMap.worldPath ~ "/map2";
        soilFile = new MmFile(soilPath, MmFile.Mode.readWrite, mapSizeBytes, null, 0);
        soilData = cast(float[])soilFile[];

        auto startTime = utime();

        float maxHeight = 10_000;
        float startAmplitude = maxHeight / 2;

        /*
        float endAmplitude = 0.5;
        int octaves = cast(int)logb(startAmplitude / endAmplitude);
        

        float endIntervall = 3;
        float startIntervall = endIntervall * 2^^octaves;
        */

        float startIntervall = 6000;
        float endIntervall = sampleIntervall;
        int octaves = cast(int)logb(startIntervall / endIntervall);
        float endAmplitude = startAmplitude * (0.5 ^^ octaves);

        float baseFrequency = 1.0f / startIntervall;


        msg("Octaves: ", octaves);
        msg("Start amplitude: ", startAmplitude);
        msg("Start intervall: ", 1.0f / baseFrequency, " | ", startIntervall);
        msg("End amplitude: ", startAmplitude * 0.5^^octaves, " | ", endAmplitude);
        msg("End intervall: ", 0.5^^octaves / baseFrequency, " | ", endIntervall);

        import random.simplex;
        auto noise = new SimplexNoise(seed);

        uint LIMIT = mapSize * mapSize;
        uint LIMIT_STEP = LIMIT / 2500;
        //for(uint i = 0; i < LIMIT; i++) {
        uint progress = 0;
        foreach(uint i, ref value ; parallel(mapData)) {
            if( (i % LIMIT_STEP) == 0) {
                progress += LIMIT_STEP;
                msg("Progress: ", 100.0f * cast(float)progress / LIMIT);
            }

            float value = 0;
            auto pos = vec2f(i % mapSize, i / mapSize);
            pos *= baseFrequency;

            float amplitude = startAmplitude;

            for(int iter = 0; iter < octaves; iter++) {
                value += amplitude * noise.getValue2(pos.convert!double);
                amplitude *= 0.5;
                pos *= 2;
            }

            mapData[i] = value;
        }

        msg("Time to make heightmap: ", (utime() - startTime) / 1_000_000.0);


        foreach(uint i, ref value ; parallel(mapData)) {
            auto x = i % mapSize;
            auto y = i / mapSize;
            auto dst = vec2f(x,y).getDistance(vec2f(mapSize * 0.5));

            mapData[i] = dst < mapSize*0.25 ? 100 : 0;
        }



        applyErosion(seed);
    }



    void applyErosion(int seed) {

        auto getMaterialConstants(int x, int y, int z) {
            int materialNum = worldMap.getStrataNum(x, y, z);
            auto material = worldMap.materials[materialNum];

            return tuple(material.dissolutionConstant, material.talusConstant);
        }

        auto ero = new Erosion();
        soilData[] = 2.0; // 2 meters worth of soil to begin with.
        ero.init(mapData, soilData, &getMaterialConstants, mapSize, mapSize, seed);

        HMap height = new HMap;
        HMap soil = new HMap;
        HMap water = new HMap;
        ero.heightMap = height;
        ero.soilMap = soil;
        ero.waterMap = water;
        water.alpha = 0.5;
        height.depth = mapSize * sampleIntervall;
        height.width = mapSize * sampleIntervall;
        soil.width = mapSize * sampleIntervall;
        soil.depth = mapSize * sampleIntervall;
        water.width = mapSize * sampleIntervall;
        water.depth = mapSize * sampleIntervall;
        // ERODE ERODE ERODE

        // Start erosion thread.
        bool done = false;
        spawnThread({
            try {
                foreach(iter ; 0 .. 5000) {
                    ero.erode();
                }
                mapData[] = ero.height[];
                soilData[] = ero.soil[];
                done = true;
            }catch(Throwable t) {
                msg("Error:\n", t);
                BREAKPOINT;
            }
        });
        Camera camera = new Camera;
        camera.setPosition(vec3d(0, 0, 20));
        camera.setTargetDir(vec3d(0.7, 0.7, 0));
        renderLoop(camera, 
                   { return done; },
                   {
                       import derelict.opengl.gl;
                       synchronized(height, soil, water) {
                           height.render(camera);
                           soil.render(camera);
                           glEnable(GL_BLEND);
                           glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
                           water.render(camera);
                           glDisable(GL_BLEND);
                       }
                   });
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
        vec2f pt = pos.value.convert!float / cast(float)sampleIntervall;
        auto get = &getMapValue!(which, true);
        static if(interpolate) {
            import random.xinterpolate;
            import random.random;
            return XInterpolate2!(SmootherInter, get)(pt);
            return XInterpolate24!(BSpline, get)(pt);
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

    /*
    ref float getHeightValue(int x, int y) {
    }

    float getHeight(bool interpolate = true)(TileXYPos pos) {
        vec2f pt = pos.value.convert!float / cast(float)sampleIntervall;
        auto get = &getHeightValue;
        static if(interpolate) {
            return XInterpolate24!(BSpline, get)(pt);
        } else {
            return get(cast(int)pt.x, cast(int)pt.y);
        }
    }
    */
}


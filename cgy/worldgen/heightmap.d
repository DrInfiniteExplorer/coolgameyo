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

enum sampleIntervall = 10; //10 meters between each sample

immutable maxHeight = 10_000;
immutable startAmplitude = maxHeight / 2;
immutable startIntervall = 6000 * sampleIntervall;
immutable endIntervall = sampleIntervall;
immutable baseFrequency = 1.0f / startIntervall;
int octaves;
float endAmplitude;

shared static this() {
    octaves = cast(int)logb(startIntervall / endIntervall);
    endAmplitude = startAmplitude * (0.5 ^^ octaves);
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
    float[] soilData; // Pointer to memory in heightmapfile.

    SimplexNoise baseHeightNoise;

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

    void load(int seed) {
        auto heightPath = worldMap.worldPath ~ "/map1";
        msg("Loading heightmap at: ", heightPath);
        heightmapFile = new MmFile(heightPath, MmFile.Mode.readWrite, mapSizeBytes, null, 0);
        mapData = cast(float[])heightmapFile[];

        auto soilPath = worldMap.worldPath ~ "/map2";
        soilFile = new MmFile(soilPath, MmFile.Mode.readWrite, mapSizeBytes, null, 0);
        soilData = cast(float[])soilFile[];

        baseHeightNoise = new SimplexNoise(seed);
    }

    float getOriginalHeight(vec2i _pos) {
        float value = 0;
        vec2f pos = _pos.convert!float;
        pos *= baseFrequency;

        float amplitude = startAmplitude;

        for(int iter = 0; iter < octaves; iter++) {
            value += amplitude * baseHeightNoise.getValue2(pos.convert!double);
            amplitude *= 0.5;
            pos *= 2;
        }

        auto dst = _pos.convert!float.getDistance(vec2f(mapSize * 0.5 * sampleIntervall));
        dst /= (mapSize*0.25 * sampleIntervall);
        //msg(dst);

        return value;
        //return dst < 1 ? 100 : 0;
        //return dst < 1 ? sqrt(1-dst^^2)*100 : 0;
        //return dst < 1 ? (1-dst)*100 : 0;
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
        //for(uint i = 0; i < LIMIT; i++) {
        size_t progress = 0;
        //foreach(uint i, ref value ; parallel(mapData)) {
        foreach(size_t i, ref value ; mapData) {
                if( (i % LIMIT_STEP) == 0) {
                progress += LIMIT_STEP;
                msg("Progress: ", 100.0f * cast(float)progress / mapSizeSQ);
            }
            auto pos = vec2i(cast(int)(i % mapSize), cast(int)(i / mapSize));
            value = getOriginalHeight(pos*sampleIntervall);
        }

        msg("h max", reduce!max(mapData));
        msg("h min", reduce!min(mapData));

        applyErosion(seed);
    }



    void applyErosion(int seed) {

        auto getMaterialConstants(int x, int y, int z) {
            int materialNum = worldMap.getStrataNum(x, y, z);
            auto material = worldMap.materials[materialNum];

            return tuple(material.dissolutionConstant, material.talusConstant);
        }

        auto ero = new GPUErosion();
        soilData[] = 2.0; // 2 meters worth of soil to begin with.
        ero.init(mapData, soilData, mapSize, mapSize, seed);

        HMap height = new HMap;
        HMap wtr = new HMap;
        ero.heightMap = height;
        ero.waterMap = wtr;
        height.depth = wtr.depth = mapSize * sampleIntervall;
        height.width = wtr.width = mapSize * sampleIntervall;
        // ERODE ERODE ERODE

        // Start erosion thread.
        bool done = false;
        Camera camera = new Camera;
        camera.farPlane *= 10;
        camera.setPosition(vec3d(0, 0, 20));
        camera.setTargetDir(vec3d(0.7, 0.7, 0));
        int c = 0;
        immutable limit = 35000;
        renderLoop(camera, 
                   { return c > limit; },
                   {
                       synchronized(height) {
                           height.render(camera);
                       }
                       synchronized(wtr) {
                           import derelict.opengl.gl;
                           
                           glEnable( GL_POLYGON_OFFSET_FILL );      
                           glPolygonOffset( 1f, 1f );

                           wtr.alpha = 0.85;
                           glEnable(GL_BLEND);
                           glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
                           
                           wtr.render(camera);
                           glDisable(GL_BLEND);
                           glDisable( GL_POLYGON_OFFSET_FILL );      
                       }
                       ero.erode();
                       c++;
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


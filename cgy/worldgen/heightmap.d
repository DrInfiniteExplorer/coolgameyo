module worldgen.heightmap;

import std.parallelism;
import std.mmfile;
import std.math;


import util.filesystem;
import util.pos;
import util.util;
import worldgen.maps;
import worldgen.strata;

enum sampleIntervall = 10; //10 meters between each sample

class HeightMaps {
    int worldSize; //In meters
    int mapSize; //In samples
    long mapSizeBytes;
    WorldMap worldMap;

    MmFile heightmapFile;
    float[] mapData; // Pointer to memory in heightmapfile.
    
    this(WorldMap _worldMap) {
        worldMap = _worldMap;
        auto size = .worldSize; // 1 mil
        worldSize = size; // In meters woah.
        mapSize = worldSize / sampleIntervall;
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
        mapData = null;
    }

    void load() {
        auto heightPath = worldMap.worldPath ~ "/map1";
        msg("Loading heightmap at: ", heightPath);
        heightmapFile = new MmFile(heightPath, MmFile.Mode.readWrite, mapSizeBytes, null, 0);
        mapData = cast(float[])heightmapFile[];
    }

    void generate(int seed) {

        auto heightPath = worldMap.worldPath ~ "/map1";
        msg("Creating heightmap at: ", heightPath);
        BREAK_IF(heightmapFile !is null);
        heightmapFile = new MmFile(heightPath, MmFile.Mode.readWriteNew, mapSizeBytes, null, 0);
        mapData = cast(float[])heightmapFile[];

        auto startTime = utime();

        float maxHeight = 10_000;
        float startAmplitude = maxHeight / 2;
        float endAmplitude = 0.5;
        int octaves = cast(int)logb(startAmplitude / endAmplitude);

        float endIntervall = 3;
        float startIntervall = endIntervall * 2^^octaves;

        startIntervall = 6000;

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
                value += amplitude * noise.getValue(pos.X, pos.Y);
                amplitude *= 0.5;
                pos *= 2;
            }

            mapData[i] = value;
        }

        msg("Time to make heightmap: ", (utime() - startTime) / 1_000_000.0);
    }

    ref float getHeightValue(int x, int y) {
        BREAK_IF(x < 0);
        BREAK_IF(y < 0);
        BREAK_IF(x >= mapSize);
        BREAK_IF(y >= mapSize);
        auto idx = y * mapSize + x;
        return mapData[idx];
    }

    float getHeight(bool interpolate = true)(TileXYPos pos) {
        import random.random : BSpline;
        import random.xinterpolate4 : XInterpolate4;
        vec2f pt = pos.value.convert!float / cast(float)sampleIntervall;
        auto get = &getHeightValue;
        static if(interpolate) {
            return XInterpolate4!(float, BSpline, get)(pt.X, pt.Y);
        } else {
            return get(cast(int)pt.X, cast(int)pt.Y);
        }
    }
}

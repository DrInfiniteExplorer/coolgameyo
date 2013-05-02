module worldgen.maps;

import core.sync.rwmutex;
import core.thread : Thread;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.math;
import std.md5;
import std.random;
import std.range : assumeSorted, SortedRange, SearchPolicy;
import std.stdio;


//import worldgen.newgen;

import json;
import graphics.image;

import materials;

import random.catmullrom;
import random.combine;
import random.gradient;
import random.gradientnoise;
import random.hybridfractal;
import random.map;
import random.modscaleoffset;
import random.random;
import random.randsource;
import random.simplex;
import random.valuemap;
import random.valuesource;
import random.vectormap;
import random.xinterpolate4;


import statistics;
import tiletypemanager;

import util.filesystem;
import util.memory;
import util.pos;
import util.rangefromto;
import util.rect;
import util.util;
import util.voronoi.fortune;
import util.voronoi.lattice;
import util.voronoi.voronoi;

import worldgen.heightmap;
import worldgen.strata;
import worldgen.worldgen;
import worldgen.worldpop;

import worldstate.worldstate;
import worldstate.heightmap;

alias ValueMap2Dd ValueMap;


/* pos 0 not used */
/* pt2tile-scale*/
//immutable ptScale = [0, 8, 32, 128 , 512 , /* start mipmaps */ 2048,  8192, 32768];
/* map2tile-scale*/ //Mipmap'ed values are farther apart, but same size as level5 (ie. worldsize)
//immutable mapScale = [0, 3200, 12800, 51200, 204800, /*start mipmaps */ 819200,  819200, 819200];

//1 mil värt av värld. Yeah.
//immutable WorldSize = 1 * 1_000;
immutable WorldSize = 2 * 25 * 1_024;
immutable SampleIntervall = 25; //10 meters between each sample
immutable TotalSamples = WorldSize / SampleIntervall;

immutable HalfWorldSize = vec3i(WorldSize/2, WorldSize/2, 0);
immutable HalfWorldSize_xy = vec2i(WorldSize/2);


final class WorldMap {

    mixin WorldGenerator;
    mixin WorldPopulation;

    HeightMaps heightMaps;
    MaterialStratum[] stratas;
    SortedRange!(MaterialStratum[], "a.depthStart < b.depthStart") sortedStratas;
    MaterialInformation*[] materials;
    int worldSeed;
    int strataSeed;
    int heightmapSeed;
    int walkSeed;
    string worldPath;

    SimplexNoise strataNoise;

    this() {
        //Try load stuff if not already loaded
        loadStrataInfo();
        loadMaterials();
        heightMaps = new HeightMaps(this);
    }

    this(int seed) {
        worldSeed = seed;
        worldPath = "worlds/" ~ to!string(seed) ~ "/map";
        this();
    }

    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }
    void destroy() {
        if(heightMaps) {
            heightMaps.destroy();
        }
        destroyed = true;
    }

    void generate() {
        setSeeds();
        if(exists(worldPath)) {
            import log : LogWarning;
            LogWarning("A folder already exists at '", worldPath, "'. Will ignore totally ignore that.");
            //rmdir(worldPath);
            //BREAKPOINT;
        }
        mkdir(worldPath);

        stratas = generateStratas(strataSeed);
        sortedStratas = assumeSorted!"a.depthStart < b.depthStart"(stratas);
        materials.length = stratas.length;
        foreach(idx, stratum ; stratas) {
            materials[idx] = &g_materials[stratum.materialName];
        }
        heightMaps.generate(heightmapSeed);

        strataNoise = new SimplexNoise(worldSeed);

        generateLife();
    }

    void loadWorld(string path) {
        enforce(existsDir(path), "A world does not exist at: " ~ path);
        worldPath = path ~ "/map";
        loadJSON(worldPath ~ "/seed.json").
            readJSONObject("worldSeed", &worldSeed);
        setSeeds();
        stratas = generateStratas(strataSeed);
        sortedStratas = assumeSorted!"a.depthStart < b.depthStart"(stratas);
        materials.length = stratas.length;
        foreach(idx, stratum ; stratas) {
            materials[idx] = &g_materials[stratum.materialName];
        }
        heightMaps.load(heightmapSeed);
        strataNoise = new SimplexNoise(worldSeed);
        loadRoads();
    }

    void setSeeds() {
        mixin(MeasureTime!"Time to init world:");
        auto rnd = new RandSourceUniform(worldSeed);
        strataSeed = rnd.get(int.min, int.max);
        heightmapSeed = rnd.get(int.min, int.max);
        walkSeed = rnd.get(int.min, int.max);
    }

    void save() {
        auto worldPath = worldPath;
        mkdir(worldPath);
        makeJSONObject("worldSeed", worldSeed).saveJSON(worldPath ~ "/seed.json");
    }





    //Assumes z=0 == surface of world and Z+ is upwards
    // May have to offset with world contour first. 
    int getStrataNum(int x, int y, int z) {
        vec2f baseHeightPos = vec2f(x, y) / (10_000); // Slowly changing wave. one(two?) cycles per 10 km.
        float baseHeightScale = 100.0f; // Undulate up to 100 meters!
        float baseHeightOffset = (strataNoise.getVal2(baseHeightPos) + 1.0f) * 0.5f * baseHeightScale;

        float depth = -z;
        depth += baseHeightOffset;

        vec3f perturbPos = vec3f(x, y, z) / 60.0f;
        float perturbStrength = 6.0;
        depth += strataNoise.getVal3(perturbPos) * perturbStrength;
        depth = max(0, depth);

        //int idx = countUntil!"a.depthStart > b"(stratas, depth) - 1;

        MaterialStratum derp = void;
        derp.depthStart = depth;
        int idx = cast(int)sortedStratas.lowerBound!(SearchPolicy.binarySearch)(derp).length;
        import globals;
        g_derp1 += idx;
        g_derp2 ++;

        return idx;
    }

    void heightOnHeight() {
        import graphics.image;
        import materials;
        import statistics;

        mixin(MeasureTime!("Time to generate "));
        int layerNum = 0;
        float depth = stratas[layerNum].thickness;
        int height = 3500;
        Image img = Image(null, 1280, height);
        vec3f color;
        int oldy=-1;
        string prevMat;
        color.set(0.5,1.0,1.0);
        color *= 255;
        foreach(x,Y, ref r, ref g, ref b, ref a ; img) {
            auto y = Y - 500;
            if(y < 0) {
                color.toColor(r, g, b);
                continue;
            }
            a = 255;
            auto layerNum = getStrataNum(x, x, -y);
            auto materialName = stratas[layerNum].materialName;
            color = g_materials[materialName].color.convert!float;
            color.toColor(r, g, b);
        }
        img.save("strata_height_on_height.bmp");
    }
    void strataNoNoise() {
        int layerNum = 0;
        float depth = stratas[layerNum].thickness;
        int height = 3500;
        Image img = Image(null, 1280, height);
        vec3f color;
        int oldy=-1;
        string prevMat;
        color.set(0.5,1.0,1.0);
        color *= 255;
        foreach(x,Y, ref r, ref g, ref b, ref a ; img) {
            auto y = Y - 500;
            if(y < 0) {
                color.toColor(r, g, b);
                continue;
            }
            a = 255;
            if(y != oldy) {
                oldy = y;
                if(depth < y) {
                    layerNum++;
                    if(layerNum == stratas.length) layerNum--;
                    msg(depth, " ", stratas[layerNum].thickness);
                    depth += stratas[layerNum].thickness;
                    color.set(0,0,0);
                } else {
                    auto materialName = stratas[layerNum].materialName;
                    if(prevMat != materialName)
                        msg(depth, " Material: ", materialName);
                    prevMat = materialName;
                    color = g_materials[materialName].color.convert!float;
                }
            }
            color.toColor(r, g, b);
            a = 255;
        }
        img.save("strata_no_noise.bmp");
    }

}


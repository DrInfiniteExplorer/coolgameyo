module worldgen.maps;

import core.sync.rwmutex;
import core.thread : Thread;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.math;
import std.md5;
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
import random.valuemap;
import random.valuesource;
import random.vectormap;
import random.xinterpolate4;


import statistics;
import tiletypemanager;

import util.filesystem;
import util.math;
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

import worldstate.worldstate;
import worldstate.heightmap;

alias ValueMap2Dd ValueMap;


/* pos 0 not used */
/* pt2tile-scale*/
//immutable ptScale = [0, 8, 32, 128 , 512 , /* start mipmaps */ 2048,  8192, 32768];
/* map2tile-scale*/ //Mipmap'ed values are farther apart, but same size as level5 (ie. worldsize)
//immutable mapScale = [0, 3200, 12800, 51200, 204800, /*start mipmaps */ 819200,  819200, 819200];

//1 mil värt av värld. Yeah.
immutable worldSize = 2 * 10 * 1_000;
//immutable worldSize = 1 * 1_000;

immutable halfWorldSize = vec3i(worldSize/2, worldSize/2, 0);
immutable halfWorldSize_xy = vec2i(worldSize/2);


final class WorldMap {

    mixin WorldGenerator;

    HeightMaps heightMaps;
    MaterialStratum[] stratas;
    MaterialInformation*[] materials;
    int worldSeed;
    int strataSeed;
    int heightmapSeed;
    string worldPath;

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
            rmdir(worldPath);
            //BREAKPOINT;
        }
        mkdir(worldPath);

        stratas = generateStratas(strataSeed);
        materials.length = stratas.length;
        foreach(idx, stratum ; stratas) {
            materials[idx] = &g_materials[stratum.materialName];
        }
        heightMaps.generate(heightmapSeed);

    }

    void loadWorld(string path) {
        enforce(existsDir(path), "A world does not exist at: " ~ path);
        worldPath = path ~ "/map";
        loadJSON(worldPath ~ "/seed.json").
            readJSONObject("worldSeed", &worldSeed);
        setSeeds();
        stratas = generateStratas(strataSeed);
        materials.length = stratas.length;
        foreach(idx, stratum ; stratas) {
            materials[idx] = &g_materials[stratum.materialName];
        }
        heightMaps.load(heightmapSeed);
    }

    void setSeeds() {
        mixin(MeasureTime!"Time to init world:");
        auto rnd = new RandSourceUniform(worldSeed);
        strataSeed = rnd.get(int.min, int.max);
        heightmapSeed = rnd.get(int.min, int.max);
    }

    void save() {
        auto worldPath = worldPath;
        mkdir(worldPath);
        makeJSONObject("worldSeed", worldSeed).saveJSON(worldPath ~ "/seed.json");
    }





    //Assumes z=0 == surface of world and Z+ is upwards
    // May have to offset with world contour first.
    int getStrataNum(int x, int y, int z) {
        BREAK_IF(z > 20);
        z = min(z, 0); // Allow for some retardedness in calculations.
        int num = 0;
        auto xyPos = vec2f(x, y);
        float depth = stratas[0].getHeight(xyPos);
        int zDepth = -z;
        while(zDepth > depth) {
            num++;
            depth += stratas[num].getHeight(xyPos);
        }
        return num;
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


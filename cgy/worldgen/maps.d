module worldgen.maps;

import core.sync.rwmutex;
import core.thread : Thread, Duration, dur;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.math;
import std.md5;
import std.stdio;


//import worldgen.newgen;

import feature.feature;
import json;
import graphics.image;

import util.pos;
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
import util.rangefromto;
import util.rect;
import util.util;
import util.voronoi.fortune;
import util.voronoi.lattice;
import util.voronoi.voronoi;

import worldgen.areas;
import worldgen.biomes;
import worldgen.heightmap;
import worldgen.layers;
import worldgen.mapviz;
import worldgen.moisture;
import worldgen.temperature;
import worldgen.wind;
import worldgen.worldgen;

import worldstate.worldstate;
import worldstate.heightmap;

alias ValueMap2Dd ValueMap;

immutable Dim = 400;
//immutable ptPerLayer = 400;
alias Dim ptPerLayer;


immutable StepIter = 4*25;

/* pos 0 not used */
/* pt2tile-scale*/
immutable ptScale = [0, 8, 32, 128 , 512 , /* start mipmaps */ 2048,  8192, 32768];
/* map2tile-scale*/ //Mipmap'ed values are farther apart, but same size as level5 (ie. worldsize)
immutable mapScale = [0, 3200, 12800, 51200, 204800, /*start mipmaps */ 819200,  819200, 819200];

immutable worldSize = mapScale[4];

immutable halfWorldSize = vec3i(worldSize/2, worldSize/2, 0);
immutable halfWorldSize_xy = vec2i(worldSize/2);


final class WorldMap {

    mixin Moisture;
    mixin worldgen.heightmap.Heightmap;
    mixin Wind;
    mixin Temperature;

    mixin Areas;
    mixin Biomes;

    mixin MapViz;
    mixin Layers;
    mixin WorldGenerator;

    //Eventually make a mixin for climate?
    Image climates;

    //Figure out a better datastructure for this. bits 0-3 holds climate information, bit 4 holds isSea'ness, bit 5 wether or not it has been sorted into a region, etc.


    int worldSeed;

    int voronoiSeed;

    this(string name) {
        init();
        load(name);
    }

    this(int seed) {
        worldSeed = seed;
        init();
    }

    string worldHash() const @property {
        return to!string(worldSeed) ~ "_";
    }

    string worldPath(string hash = null) const @property{

        return "worlds/" ~ ((hash is null) ? worldHash() : hash);
    }

    void save() {
        auto worldPath = worldPath;
        mkdir(worldPath);

        getVisualizer().getClimateImage().save(worldPath ~ "/map.tga");
        saveHeightmap();
        saveAreas();
        saveWindMap();
        saveTemperatureMap();
        saveMoistureMap();
        saveAllFeatures();
    }

    //We always initialize before we call load.
    void load(string worldHash) {
        auto path = worldPath(worldHash);        
        enforce(existsDir(path), "WorldState not found:" ~ path);

        worldSeed = to!int( split(worldHash, "_")[0] );
        initSeed();

        loadHeightmap();
        loadAreas();
        loadWindMap();
        loadTemperatureMap();
        loadMoistureMap();
        loadAllFeatures();
    }

    public static string[] enumerateSavedWorlds() {
        if(!exists("worlds/")) {
            return null;
        }
        string[] ret;
        dir("worlds/", (string s) {ret ~= s;});
        return ret;
    }

    public static Image getWorldImage(string name) {
        return Image("worlds/" ~ name ~ "/map.tga");
    }

    // We always initialize, then we call either generate or load.
    void init() {
        climates = Image("climateMap.bmp");
        mixin(MeasureTime!"Time to init world:");
        //Spans 1.0*worldHeight
        initSeed();

        heightmapInit();
        windInit();
        temperatureInit();
        moistureInit();
        areasInit();
        layersInit();

    }

    // We always call init before generate.
    void generate() {

        generateHeightMap();
        generateWindMap();
        generateTemperatureMap();
        generateMoistureMap();
        generateAreas(); //Also classifies them.
        generateTopLayerFeatures();
    }

    void initSeed() {
        auto rnd = new RandSourceUniform(worldSeed);
        heightSeed = rnd.get(int.min, int.max);
        windSeed = rnd.get(int.min, int.max);
        voronoiSeed = rnd.get(int.min, int.max);
        layerSeed = rnd.get(int.min, int.max);
    }

    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {
        destroyed = true;
    }


}


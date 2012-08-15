module worldgen.maps;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.math;
import std.md5;
import std.stdio;


//import worldgen.newgen;

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

import graphics.image;

import json;
import pos;
import statistics;
import tiletypemanager;

import util.filesystem;
import util.math;
import util.rangefromto;
import util.rect;
import util.util;
import util.voronoi.wrapper;

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
immutable ptScale = [0, 32, 128, 512, 2048, 8192, /*start mipmaps*/ 32768, 131072];
/* map2tile-scale*/ //Mipmap'ed values are farther apart, but same size as level5 (ie. worldsize)
immutable mapScale = [0, 12800, 51200, 204800, 819200, 3276800, /*start mipmaps*/ 3276800, 3276800];

immutable worldSize = mapScale[5];

immutable halfWorldSize = vec3i(mapScale[5]/2, mapScale[5]/2, 0);
immutable halfWorldSize_xy = vec2i(mapScale[5]/2, mapScale[5]/2);


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
        saveWindMap();
        saveTemperatureMap();
        saveMoistureMap();
        saveAreas();
    }

    void load(string worldHash) {
        auto path = worldPath(worldHash);        
        enforce(existsDir(path), "WorldState not found:" ~ path);

        worldSeed = to!int( split(worldHash, "_")[0] );
        initSeed();

        loadHeightmap();
        loadWindMap();
        loadTemperatureMap();
        loadMoistureMap();
        loadAreas();
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

    void generate() {

        generateHeightMap();
        generateWindMap();
        generateTemperatureMap();
        generateMoistureMap();

        generateAreas();

        generateTopLayer();
    }

    void initSeed() {
        auto rnd = new RandSourceUniform(worldSeed);
        heightSeed = rnd.get(int.min, int.max);
        windSeed = rnd.get(int.min, int.max);
        voronoiSeed = rnd.get(int.min, int.max);
    }

    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {
        destroyed = true;
    }




    void step() {
        classifyAreas();
        return;
    }
}


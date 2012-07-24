module worldgen.maps;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.math;


//import worldgen.newgen;

import random.catmullrom;
import random.combine;
import random.gradient;
import random.gradientnoise;
import random.hybridfractal;
import random.map;
import random.random;
import random.randsource;
import random.valuemap;
import random.valuesource;
import random.vectormap;

import graphics.image;

import json;

import statistics;

import util.filesystem;
import util.rangefromto;
import util.util;
import util.voronoi.wrapper;

import worldgen.moisture;
import worldgen.heightmap;
import worldgen.wind;
import worldgen.temperature;
import worldgen.areas;
import worldgen.mapviz;

alias ValueMap2Dd ValueMap;

enum Dim = 400;
enum StepIter = 4*25;

final class World {

    mixin Moisture;
    mixin Heightmap;
    mixin Wind;
    mixin Temperature;

    mixin Areas;

    mixin MapViz;

    //Figure out a better datastructure for this. bits 0-3 holds climate information, bit 4 holds isSea'ness, bit 5 wether or not it has been sorted into a region, etc.


    int worldSeed = 880128;

    int voronoiSeed;

    string getWorldHash() const @property {
        return to!string(worldSeed) ~ "_";
    }

    string worldPath(string hash = null) const @property{

        return "worlds/" ~ ((hash is null) ? getWorldHash() : hash);
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
        enforce(existsDir(path), "World not found:" ~ path);

        worldSeed = to!int( split(worldHash, "_")[0] );
        initSeed();

        loadHeightmap();
        loadWindMap();
        loadTemperatureMap();
        loadMoistureMap();
        loadAreas();
    }

    public static string[] enumerateSavedWorlds() {
        string[] ret;
        dir("worlds/", (string s) {ret ~= s;});
        return ret;
    }

    void init() {
        mixin(MeasureTime!"Time to init world:");
        //Spans 1.0*worldHeight
        initSeed();

        heightmapInit();
        windInit();
        temperatureInit();
        moistureInit();
        areasInit();


        generateHeightMap();
        generateWindMap();
        generateTemperatureMap();
        generateMoistureMap();

        generateAreas();
    }

    void initSeed() {
        auto rnd = new RandSourceUniform(worldSeed);
        heightSeed = rnd.get(int.min, int.max);
        windSeed = rnd.get(int.min, int.max);
        voronoiSeed = rnd.get(int.min, int.max);
    }

    void destroy() {
    }


    void step() {
        classifyAreas();
        return;
    }
}


module worldgen.maps;

import std.algorithm;
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

    void save() {
    }

    void load() {
    }

    void init() {
        //Spans 1.0*worldHeight
        heightmapInit();
        temperatureInit();

        auto rnd = new RandSourceUniform(worldSeed);
        heightSeed = rnd.get(int.min, int.max);
        windSeed = rnd.get(int.min, int.max);
        voronoiSeed = rnd.get(int.min, int.max);

        generateHeightMap();
        generateWindMap();
        generateTemperatureMap();
        generateMoistureMap();

        generateAreas();
    }

    void destroy() {
    }


    void step() {
        classifyAreas();
        return;
    }

}


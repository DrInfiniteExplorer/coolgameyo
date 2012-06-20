module worldgen.maps;

import std.algorithm;

import util.util;

//import worldgen.newgen;

import random.valuemap;
import random.vectormap;
import random.combine;
import random.random;
import random.randsource;
import random.gradient;
import random.gradientnoise;
import random.hybridfractal;
import random.map;

alias ValueMap2Dd ValueMap;

final class World {

    ValueMap heightMap;
    ValueMap moistureMap;
    ValueMap temperatureMap;

    Vector2DMap2D!(double, true) windMap;

    ValueMap rainMap;

    double worldHeight = 10_000;
    double worldMin;
    double worldMax;


    void save() {
    }

    void load() {
    }

    void init() {
        //Spans 1.0*worldHeight
        worldMin = -0.3*worldHeight;
        worldMax =  0.7*worldHeight;
 
        generateHeightMap();
        generateTemperatureMap();
        generateWindMap();
        generateHumidityMap();

    }

    void generateHeightMap() {
        auto randomField = new ValueMap;
        auto gradient = new GradientNoise01!()(400, new RandSourceUniform(880128));
        auto hybrid = new HybridMultiFractal(gradient, 0.1, 2, 6, 0.1);
        hybrid.setBaseWaveLength(80);

        heightMap = new ValueMap(400, 400);
        heightMap.fill(hybrid, 400, 400);
        heightMap.normalize(worldMin, worldMax); 
    }

    void generateTemperatureMap() {
        auto equatorDistanceField = new PlanarDistanceField(vec3d(0, 200, 0), vec3d(0, 1, 0));
        auto equatorChillField = new Map(equatorDistanceField, d => 40 - (d<0?-d:d)*60/200 );

        //Every 1000 meter gets about 10 degree colder
        // http://www.marietta.edu/~biol/biomes/biome_main.htm
        auto heightChillField = new Map(heightMap, d => d < 0 ? -10 : -d/100);

        auto temperatureField = new CombineAdd(equatorChillField, heightChillField);

        temperatureMap = new ValueMap(400, 400);
        temperatureMap.fill(temperatureField, 400, 400);

    }

    //Wind map temporary during world generation
    //Is map of smoothly varying 2d-vectors
    //Bigger length of vectors the closer they are to the sea
    //Add jet stream manually
    //Let the map affect itself (term for this..)
        //Use temperature map to affect with?
        //Or only do that later when making humidity map?
    void generateWindMap() {
        auto randomField = new ValueMap;
        auto gradient = new GradientNoise!()(400, new RandSourceUniform(880128));
        auto gradient2 = new GradientNoise!()(400, new RandSourceUniform(821088));

        auto hybrid1 = new HybridMultiFractal(gradient, 0.7, 2, 4, 0);
        hybrid1.setBaseWaveLength(100);
        auto hybrid2 = new HybridMultiFractal(gradient2, 0.7, 2, 4, 0);
        hybrid2.setBaseWaveLength(100);

        windMap = new typeof(windMap)(400, 400);
        windMap.fill(hybrid1, hybrid2, 400, 400);
        windMap.normalize(0, 10);

    }

    void generateHumidityMap() {
        //Initialize rainfall map to 0
        //Iterate!!
                //If above sea and warm, take water
                //If above land, rain water
                //If above land and moving upwards, rain more water!
                //If above land and has not much water, take moisture..
                //Be transformed by the wind map
                //Affect temperature?
                //Let wind map be affected by temperature?
    }

}


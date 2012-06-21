module worldgen.maps;

import std.algorithm;
import std.math;

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
import random.valuesource;

alias ValueMap2Dd ValueMap;

final class World {

    ValueMap heightMap;
    ValueMap moistureMap;
    ValueMap temperatureMap;
    Vector2DMap2D!(double, true) windMap;
    ValueMap rainMap;

    int worldSeed = 880128;
    double worldHeight = 10_000;

    int heightSeed;
    int windSeed;
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

        auto rnd = new RandSourceUniform(worldSeed);
        heightSeed = rnd.get(int.min, int.max);
        windSeed = rnd.get(int.min, int.max);

        auto randomField = new ValueMap;
        auto gradient = new GradientNoise01!()(400, new RandSourceUniform(heightSeed));
        auto hybrid = new HybridMultiFractal(gradient, 0.1, 2, 6, 0.1);
        hybrid.setBaseWaveLength(80);

        auto test = new DelegateSource((double x, double y, double z) {
            auto height = hybrid.getValue(x, y);
            auto xDist =  abs(200 - x);
            auto xBorderDistance = 200 - xDist;
            auto yDist =  abs(200 - y);
            auto yBorderDistance = 200 - yDist;

            enum limit = 25.0;
            enum limitSQ = limit ^^ 2.0;
            if(xBorderDistance < limit) {
                auto xLimitDistance = limit - xBorderDistance;
                auto ratio = (limitSQ - xLimitDistance^^2.0) / limitSQ;
                height *= ratio;
            }
            if(yBorderDistance < limit) {
                auto yLimitDistance = limit - yBorderDistance;
                auto ratio = (limitSQ - yLimitDistance^^2.0) / limitSQ;
                height *= ratio;
            }
            return height;
        });


        heightMap = new ValueMap(400, 400);
        heightMap.fill(test, 400, 400);
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
        auto windRnd = new RandSourceUniform(windSeed);
        auto gradient = new GradientNoise!()(400, windRnd);
        auto gradient2 = new GradientNoise!()(400, windRnd);

        auto hybrid1 = new HybridMultiFractal(gradient, 0.7, 2, 4, 0);
        hybrid1.setBaseWaveLength(100);
        auto hybrid2 = new HybridMultiFractal(gradient2, 0.7, 2, 4, 0);
        hybrid2.setBaseWaveLength(100);

        auto hybridCombo = new DelegateSource2D( (double x, double y, double z) {
            auto rand = vec2d(hybrid1.getValue(x,y,z), hybrid2.getValue(x,y,z));
            auto grad = heightMap.centralGradient(x,y, 1.0)*10;
            return grad;
            //return rand + grad;
        });

        windMap = new typeof(windMap)(400, 400);
        windMap.fill(hybridCombo, 400, 400);
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


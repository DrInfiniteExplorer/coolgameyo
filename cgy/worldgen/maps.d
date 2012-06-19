module worldgen.maps;

import std.algorithm;

import util.util;

//import worldgen.newgen;

import random.valuemap;
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

    ValueMap windMap;
    ValueMap rainMap;



    void save() {
    }

    void load() {
    }

    void init() {

        generateHeightMap();
        generateTemperatureMap();
        generateWindMap();
        generateHumidityMap();
    }

    void generateHeightMap() {
        auto randomField = new ValueMap;
        auto gradient = new GradientNoise01!()(400, new RandSourceUniform(880128));
        auto ridged = new HybridMultiFractal(gradient, 0.1, 2, 6, 0.1);
        ridged.setBaseWaveLength(80);
        heightMap = new ValueMap(400, 400);
        heightMap.fill(ridged, 400, 400);
        heightMap.normalize(0, 1.0);
    }

    void generateTemperatureMap() {
        auto equatorDistanceField = new PlanarDistanceField(vec3d(0, 200, 0), vec3d(0, 1, 0));
        auto equatorChillField = new Map(equatorDistanceField, d => 40 - (d<0?-d:d)*60/200 );

        auto heightChillField = new Map(heightMap, d => d/1);

        auto temperatureField = new CombineAdd(equatorChillField, heightChillField);

        temperatureMap = new ValueMap(400, 400);
        temperatureMap.fill(temperatureField, 400, 400);
        //temperatureMap.fill(equatorDistanceField, 400, 400);
        //For each pos;
            //temp = distance from equator - 10*(height/1000)
    }

    //Wind map temporary during world generation
    //Is map of smoothly varying 2d-vectors
    //Bigger length of vectors the closer they are to the sea
    //Add jet stream manually
    //Let the map affect itself (term for this..)
        //Use temperature map to affect with?
        //Or only do that later when making humidity map?
    void generateWindMap() {
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


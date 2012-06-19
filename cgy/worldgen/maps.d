module worldgen.maps;



import worldgen.newgen;

import random.valuemap;
import random.random;
import random.randsource;
import random.gradientnoise;
import random.hybridfractal;

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
        heightMap = new ValueMap(400, 400);
        auto gradient = new GradientNoise01!()(400, new RandSourceUniform(880128));
        auto ridged = new HybridMultiFractal(gradient, 0.1, 2, 6, 0.1);
        ridged.setBaseWaveLength(80);
        heightMap.fill(ridged, 400, 400);
        heightMap.normalize(0, 1.0);
    }

    void generateTemperatureMap() {
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


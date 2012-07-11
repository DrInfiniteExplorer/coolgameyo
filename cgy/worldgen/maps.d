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

    double temperatureMin;
    double temperatureMax;
    double temperatureRange;


    void save() {
    }

    void load() {
    }

    void init() {
        //Spans 1.0*worldHeight
        worldMin = -0.3*worldHeight;
        worldMax =  0.7*worldHeight;

        temperatureMin = -20;
        temperatureMax = 40;
        temperatureRange = temperatureMax - temperatureMin;
 
        generateHeightMap();
        generateTemperatureMap();
        generateWindMap();
        generateMoistureMap();

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
        auto equatorChillField = new Map(equatorDistanceField, d => temperatureMax - (d<0?-d:d)*temperatureRange/200 );

        //Every 1000 meter gets about 10 degree colder
        // http://www.marietta.edu/~biol/biomes/biome_main.htm
        auto heightChillField = new Map(heightMap, d => d < 0 ? -10 : -d/100);

        auto temperatureField = new CombineAdd(equatorChillField, heightChillField);

        temperatureMap = new ValueMap(400, 400);
        temperatureMap.fill(temperatureField, 400, 400);

    }


    //So as not to take too much time, just use a prevalent wind from east with some noise.
    void generateWindMap() {
        auto randomField = new ValueMap;
        auto windRnd = new RandSourceUniform(windSeed);
        auto gradientNoise = new GradientNoise!()(400, windRnd);

        auto hybridCombo = new DelegateSource2D( (double x, double y, double z) {
            auto dir = vec2d(-1.0, gradientNoise.getValue(x/40.0, y/40.0));
            return dir;
        });

        windMap = new typeof(windMap)(400, 400);
        windMap.fill(hybridCombo, 400, 400);
        windMap.normalize(0.8, 1.2); 
    }


    void step() {
        foreach(x ; 0 .. 100) {
            stepWind();
        }
    }

    ValueMap tmp;
    void stepWind() {
        if(tmp is null) {
            tmp = new ValueMap(400,400);
        }
        windMap.advectValueField(temperatureMap, tmp);
        temperatureMap.foreachDo!(typeof(tmp), "+=0.1*")(tmp, 400, 400);



        foreach(y ; 0 .. 400) {
            foreach(x ; 0 .. 400) {

                /*

                double up = 0.0;
                double down = 0.0;

                auto height = heightMap.get(x, y);
                bool atSea = height <= 0.0;
                auto temp = temperatureMap.get(x, y);

                vec2d windDir = windMap.get(x, y);
                double slope = windDir.dotProduct(heightMap.upwindGradient(x, y, windDir.X, windDir.Y, 1.0));

                auto moisture = moistureMap.get(x, y);
                auto rain = rainMap.get(x, y);

                auto tempModifier = clamp(temp/temperatureMax, 0.0, 1.0); //Depending on temp, stuff happens differently.
                tempModifier *= 0.25; //Temp can change up to 25%!!

                auto slopeRainModifier = 0.0;
                auto slopeDissapationModifier = 0.0;
                if(slope > 0 ) {
                    slopeRainModifier = slope / (worldMax * 0.75); //make it drop to about 0% fallabel rain at 85% of worldheight. (75 slope + 10 default)
                } else {
                    slopeDissapationModifier = -slope / (worldMax * 0.25); // When going down, steal less than when going up.
                }

                up += moisture * clamp(0.05 + slopeDissapationModifier + tempModifier, 0.0, 1.0); // 5% dissapation (?)                
                down += rain * clamp(0.10 + slopeRainModifier + tempModifier, 0.0, 1.0); //10% rainfall?

                moisture = moisture + down - (atSea ? 0.0 : up);
                rain = rain + up - down;

                //Amount going down.
                moistureMap.set(x, y, moisture);
                rainMap.set(x, y, rain);

                */


            }
        }


    }

    void generateMoistureMap() {
        moistureMap = new ValueMap(400, 400);
        moistureMap.fill((double x, double y) { return heightMap.getValue(x, y) <= 0 ? 10_000 : 10; }, 400, 400);


        rainMap = new ValueMap(400, 400);
        rainMap.fill((double x, double y) { return 0.0; }, 400, 400);
    }

}


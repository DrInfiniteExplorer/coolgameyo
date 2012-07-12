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

enum Dim = 400;
enum StepIter = 4*25;

final class World {

    ValueMap heightMap;
    ValueMap moistureMap;
    ValueMap temperatureMap;
    ValueMap windTemperatureMap;
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
        auto gradient = new GradientNoise01!()(Dim, new RandSourceUniform(heightSeed));
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


        heightMap = new ValueMap(Dim, Dim);
        heightMap.fill(test, Dim, Dim);
        heightMap.normalize(worldMin, worldMax); 
    }

    void generateTemperatureMap() {
        auto equatorDistanceField = new PlanarDistanceField(vec3d(0, 200, 0), vec3d(0, 1, 0));
        auto equatorChillField = new Map(equatorDistanceField, d => temperatureMax - (d<0?-d:d)*temperatureRange/200 );

        //Every 1000 meter gets about 10 degree colder
        // http://www.marietta.edu/~biol/biomes/biome_main.htm
        auto heightChillField = new Map(heightMap, d => d < 0 ? -10 : -d/100);

        auto temperatureField = new CombineAdd(equatorChillField, heightChillField);

        temperatureMap = new ValueMap(Dim, Dim);
        windTemperatureMap = new ValueMap(Dim, Dim);
        temperatureMap.fill(temperatureField, Dim, Dim);
        windTemperatureMap.fill(temperatureMap, Dim, Dim);

    }


    //So as not to take too much time, just use a prevalent wind from east with some noise.
    void generateWindMap() {
        auto randomField = new ValueMap;
        auto windRnd = new RandSourceUniform(windSeed);
        auto gradientNoise = new GradientNoise!()(Dim, windRnd);

        auto hybridCombo = new DelegateSource2D( (double x, double y, double z) {
            auto dir = vec2d(-1.0, gradientNoise.getValue(x/40.0, y/40.0));
            return dir;
        });

        windMap = new typeof(windMap)(Dim, Dim);
        windMap.fill(hybridCombo, Dim, Dim);
        windMap.normalize(0.8, 1.2); 
    }


    void step() {
        foreach(x ; 0 .. StepIter) {
            stepWind();
        }
        temperatureMap.randMap[] = temperatureMap.randMap[] * 0.9 + windTemperatureMap.randMap[] * 0.1;
    }

    ValueMap tmp;
    void stepWind() {
        if(tmp is null) {
            tmp = new ValueMap(Dim,Dim);
        }
        windMap.advectValueField(windTemperatureMap, tmp);
        windTemperatureMap.randMap[] += 0.1 * tmp.randMap[];

        foreach(y ; 0 .. Dim) {
            foreach(x ; 0 .. Dim) {

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
                if(!atSea) {
                    if(slope > 0 ) {
                        slopeRainModifier = slope / (worldMax * 0.75); //make it drop to about 0% fallabel rain at 85% of worldheight. (75 slope + 10 default)
                    } else {
                        slopeDissapationModifier = -slope / (worldMax * 0.25); // When going down, steal less than when going up.
                    }
                }

                up += moisture * clamp(0.05 + slopeDissapationModifier + tempModifier, 0.0, 1.0); // 5% dissapation (?)                
                down += rain * clamp(0.10 + slopeRainModifier + tempModifier, 0.0, 1.0); //10% rainfall?

                moisture = moisture + (atSea ? 0.0 : down - up);
                rain = rain + up - down;

                //Amount going down.
                moistureMap.set(x, y, moisture);
                rainMap.set(x, y, rain);
            } 
        }

        windMap.advectValueField(rainMap, tmp);
        rainMap.randMap[] += 0.2 * tmp.randMap[];

    }

    void generateMoistureMap() {
        moistureMap = new ValueMap(Dim, Dim);
        moistureMap.fill((double x, double y) { return heightMap.getValue(x, y) <= 0 ? 10 : 4; }, Dim, Dim);


        rainMap = new ValueMap(Dim, Dim);
        rainMap.fill((double x, double y) { return 0.0; }, Dim, Dim);
    }

}


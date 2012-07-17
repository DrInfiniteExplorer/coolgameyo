module worldgen.maps;

import std.algorithm;
import std.math;


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

import util.rangefromto;
import util.util;
import util.voronoi.wrapper;

alias ValueMap2Dd ValueMap;

enum Dim = 400;
enum StepIter = 4*25;

final class World {

    ValueMap heightMap;
    ValueMap moistureMap;
    ValueMap temperatureMap;
    ValueMap windTemperatureMap;
    Vector2DMap2D!(double, true) windMap;

    VoronoiWrapper bigVoronoi;

    int worldSeed = 880128;
    double worldHeight = 10_000;

    int heightSeed;
    int windSeed;
    int voronoiSeed;
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

        auto rnd = new RandSourceUniform(worldSeed);
        heightSeed = rnd.get(int.min, int.max);
        windSeed = rnd.get(int.min, int.max);
        voronoiSeed = rnd.get(int.min, int.max);

        generateHeightMap();
        generateWindMap();
        generateTemperatureMap();
        generateMoistureMap();

        generateBigVoronoi();

    }

    void generateHeightMap() {

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

    void generateTemperatureMap() {
        auto equatorDistanceField = new PlanarDistanceField(vec3d(0, 200, 0), vec3d(0, 1, 0));
        auto equatorChillField = new Map(equatorDistanceField, d => temperatureMax - (d<0?-d:d)*temperatureRange/200 );

        //Every 1000 meter gets about 10 degree colder
        // http://www.marietta.edu/~biol/biomes/biome_main.htm
        auto heightChillField = new Map(heightMap, d => d < 0 ? -10 : -d/100);

        double combine(double x, double y) {
            double grad = 0.0;
            if(heightMap.get(cast(int)x, cast(int) y) > 0.0 ) {
                auto wind = windMap.get(cast(int)x, cast(int)y);
                grad = wind.dotProduct(heightMap.upwindGradient(x, y, wind.X, wind.Y)) * 0.05;
            }

            return equatorChillField.getValue(x, y) + heightChillField.getValue(x, y) - grad;
        }

        temperatureMap = new ValueMap(Dim, Dim);
        windTemperatureMap = new ValueMap(Dim, Dim);
        temperatureMap.fill(&combine, Dim, Dim);
        windTemperatureMap.fill(temperatureMap, Dim, Dim);
    }


    void generateMoistureMap() {
        moistureMap = new ValueMap(Dim, Dim);
        moistureMap.fill((double x, double y) {
            double grad = 0.0;
            if(heightMap.get(cast(int)x, cast(int) y) <= 0.0 ) {
                return 10;
            }
            auto wind = windMap.get(cast(int)x, cast(int)y);
            grad = wind.dotProduct(heightMap.upwindGradient(x, y, wind.X, wind.Y)) * 0.05;
            return 4 + grad;

        }, Dim, Dim);

    }

    void generateBigVoronoi() {
        bigVoronoi = new VoronoiWrapper(Dim/4, Dim/4, voronoiSeed);
        bigVoronoi.setScale(vec2d(Dim));

    }


    //Figure out a better datastructure for this. bits 0-3 holds climate information, bit 4 holds isSea'ness, bit 5 wether or not it has been sorted into a region, etc.
    ubyte[Dim*Dim/16] bigVoronoiClimates;

    final class Region {
        int[] areas;

        void addArea(int area) {
            areas ~= area;
        }


    }

    Region[] regions;


    void classifyBigVoronoi() {
        auto poly = bigVoronoi.poly;
        double temp[Dim*Dim/16];
        double moisture[Dim*Dim/16];
        double count[Dim*Dim/16];
        bool isSea[Dim*Dim/16];
        isSea[] = true;
        temp[] = 0;
        moisture[] = 0;
        count[] = 0;
        foreach(x, y ; Range2D(0, 400, 0, 400)) {
            int cellId = bigVoronoi.identifyCell(vec2d(x, y));
            temp[cellId] += temperatureMap.get(x, y);
            moisture[cellId] += moistureMap.get(x, y);
            count[cellId] += 1;
            if(heightMap.get(x, y) > 0) {
                isSea[cellId] = false;
            }
        }
        temp[] /= count[];
        moisture[] /= count[];
        foreach(idx ; 0 .. Dim*Dim/16) {
            int tempIdx = clamp(cast(int)((temp[idx]-temperatureMin)*4 / temperatureRange), 0, 3);
            int moistIdx = clamp(cast(int)(moisture[idx]*4.0/10.0), 0, 3);
            //msg(temp[Idx], " ", moisture[Idx]);
            if(isSea[idx]) {
                bigVoronoiClimates[idx] = 1<<4;
            } else {
                bigVoronoiClimates[idx] = cast(ubyte)(tempIdx + (moistIdx << 2));
            }
        }

        foreach(idx ; 0 .. Dim*Dim/16) {
            int tmp = bigVoronoiClimates[idx];
            bool sorted = (tmp & (1 << 5)) != 0;
            if(sorted) continue;

            Region region = new Region;
            regions ~= region;

            //Floodfill from this area to all of the same type.
            int climateType = tmp & 0x1F;
            bool[int] visited;
            bool[int] toVisit;
            toVisit[idx] = true;
            while(toVisit.length > 0) {
                int area = toVisit.keys[0];
                toVisit.remove(area);
                int areaInfo = bigVoronoiClimates[area];
                int areaClimateType = areaInfo & 0x1F;
                if(areaClimateType != climateType) continue;
                region.addArea(area);
                areaInfo |= (1 << 5);
                bigVoronoiClimates[area] = cast(ubyte)areaInfo;
                visited[area] = true;
                foreach(neighbor ; bigVoronoi.poly.sites[area].getNeighbors()) {
                    if(neighbor is null) continue;
                    if( neighbor.siteId in visited) continue;
                    toVisit[neighbor.siteId] = true;
                }
            }
        }

    }

    void step() {
        classifyBigVoronoi();
        return;
    }

}


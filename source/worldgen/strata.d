module worldgen.strata;


import std.algorithm : min, max, clamp;
import std.math : abs;

import cgy.logger.log;
import random.gradientnoise;
import random.simplex;
import random.valuesource;

import cgy.math.vector : vec2f;
import cgy.util.util : msg;

float pmin = 12931923123.0f;
float pmax = -12931923123.0f;

alias SimplexNoise RandomType;

struct MaterialStratum {
    string materialName;
    float depthStart;



    float thickness;
    float baseIntervall;
    byte octaves;
    float threshold;
    bool randSource01;
    SimplexNoise noise;
    //Extra information that makes awesome stuff happen. Absolute value to make 2d lavastreams? etc! :D

    float getHeight(vec2f position) {
        float value = 0;
        float frequency = 1.0f / baseIntervall;
        auto pos = position;
        pos *= frequency;
        float amplitude = void;
        if(randSource01) {
            amplitude = 0.5; //Max will be 1.0 then, minimum will be 0.0
            for(int iter = 0; iter < octaves; iter++) {
                value += amplitude * (noise.getVal2!float(pos) * 0.5f + 0.5f);
                amplitude *= 0.5;
                pos *= 2;
                frequency *= 2;
            }
            //pmin = min(pmin, value);
            //pmax = max(pmax, value);
            //msg("01: ", value, " ", pmin, " ", pmax);
            value = (value*0.4+0.8 - threshold) * thickness; //80% guaranteed, may reach 120%
        } else {
            amplitude = 0.5; //Max will be 1.0 then, minimum will be -1.0
            for(int iter = 0; iter < octaves; iter++) {
                value += amplitude * noise.getValue2(pos.convert!double);
                amplitude *= 0.5;
                pos *= 2;
                frequency *= 2;
            }
            //msg("11: ", value);
            value = (value*0.2 + 1.0f - threshold) * thickness; //50% guaranteed, may reach 150%
        }

        return max(0, value);
    }
}

struct LayerInformation {
    string[] basicTypes;
}


__gshared LayerInformation g_SoilTypes;
__gshared LayerInformation g_SedimentaryTypes;
__gshared LayerInformation g_ExtrusiveTypes;
__gshared LayerInformation g_MetamorphicTypes;
__gshared LayerInformation g_IntrusiveTypes;

import cgy.json;
import cgy.util.filesystem;
import std.path;

shared static bool strataLoaded = false;
void loadStrataInfo() {
    if(strataLoaded) {
        Log("Attempting to load layer info twice");
        return;
    }
    strataLoaded = true;
    try {
        loadJSON("data/layers/soils.json").read(g_SoilTypes);
        loadJSON("data/layers/sedimentary.json").read(g_SedimentaryTypes);
        loadJSON("data/layers/extrusive.json").read(g_ExtrusiveTypes);
        loadJSON("data/layers/metamorphic.json").read(g_MetamorphicTypes);
        loadJSON("data/layers/intrusive.json").read(g_IntrusiveTypes);
    } catch(Exception e) {
        LogError("Exception loading layer information: ", e.msg);
    }
}

import std.random;
Random gen;
string prevMaterialName;

auto generateStratas(int seed) {


    immutable targetDepth = 5000.0f; //Lets say 2 kilometers worth of depth is enough for now! :p
    immutable averageThickness = 100.0f;
    immutable min = averageThickness - 75.0f;
    immutable max = averageThickness + 75.0f;
    immutable sedimentaryLimit = 1500.0f;

    //alias GradientNoise!() RandomType;

    //immutable seedFunc = 880128;
    //alias seedFunc awesomeSeed;
    alias unpredictableSeed seedFunc;

    //seed = seedFunc
    gen.seed(seed);

    static auto getRandomType(LayerInformation layer) {
        while(true) {
            auto id = uniform(0, layer.basicTypes.length, gen);
            auto selected = layer.basicTypes[id];
            if(selected != prevMaterialName) {
                prevMaterialName = selected;
                //msg("Selected ", selected);
                return selected;
            }
        }
    }

    float depth = 0.0;

    MaterialStratum[] strata;


    //First a few layers of soil. Quite thin layers mind you! :)
    //Then a sedimentary or extrusive layer
    //Then random layers until the depth is reached.
    // (Until i figure out a better way to handle it :P)
    MaterialStratum stratum;


    immutable soilLayerThickness = 3.0f;
    immutable soilLayers = 5;

    //Add soil after erosion???? :D
    /*
    foreach(i ; 0 .. soilLayers) {
        stratum.materialName = getRandomType(g_SoilTypes);
        stratum.thickness = soilLayerThickness;
        stratum.baseIntervall = (i+1) * 100;
        stratum.octaves = 3;
        stratum.threshold = 0.0f;
        stratum.randSource01 = true;
        stratum.noise = new RandomType(seedFunc);
        strata ~= stratum;
    }
    depth += soilLayers * soilLayerThickness;
    */

    static float layerDepth(float depth, ref Random gen) {
        //About 5-10 meters the first 50 meters
        //Then 10-15 meters until 100 meters
        // Then 10-20 meters until 150 meters
        // Then 10-25 meters until 200 meters
        // Im starting to see a pattern emerging here!
        // At 200 meters, ranges from 10 to 50 meters.
        // At 350 meters, ranges from 25 to 150 meters
        // Limit at above range
        if(depth <= 50) {
            return uniform(5, 10, gen);
        } else if(depth <= 100) {
            return uniform(10, 15, gen);
        } else if(depth <= 150) {
            return uniform(10, 20, gen);
        } else if(depth <= 200) {
            return uniform(10, 25, gen);
        } else if(depth <= 350) {
            return uniform(10, 50, gen);
        }
        return uniform(25, 150, gen);
    }

    float magmaDepth = 0.0;
    string prevMaterial;
    while(depth < targetDepth) {
        //msg("depth: ", depth, " ", targetDepth);
        auto sedimentChance = clamp( 0.8 - depth / 3000.0, 0.0, 1.0);
        auto extrusiveChance = clamp(0.2 - depth / 1000.0, 0.0, 1.0);
        auto metamorphChance = clamp(0.05 + depth / 2000.0, 0.0, 0.7);
        auto intrusiveChance = clamp(0.05 + depth / 1500.0, 0.0, 0.5);
        auto magmaChance = clamp(0.05 + depth / 1500.0, 0.0, 0.5);
        auto magmaDistanceMod = (depth - magmaDepth);
        if(magmaDistanceMod > 100) magmaDistanceMod = clamp( (magmaDistanceMod-100.0)/100.0, 0.0, 1.0);
        else magmaDistanceMod = clamp(abs(40.0-magmaDistanceMod)/13.0, 0.0, 1.0);
        magmaChance = clamp(magmaChance * magmaDistanceMod, 0.0, 1.0);
        auto randTypeNum = dice(gen, sedimentChance, extrusiveChance, metamorphChance, intrusiveChance, magmaChance);
        switch(randTypeNum) {
            case 0:
                if(depth > sedimentaryLimit) continue;
                stratum.materialName = getRandomType(g_SedimentaryTypes);
                stratum.thickness = layerDepth(depth, gen);
                stratum.baseIntervall = 1000.0f;
                stratum.octaves = 5;
                stratum.threshold = 0.0f;
                stratum.randSource01 = true;
                break;
            case 1:
                stratum.materialName = getRandomType(g_ExtrusiveTypes);
                stratum.thickness = uniform(5, 15, gen);
                stratum.baseIntervall = 1000.0f;
                stratum.octaves = 2;
                stratum.threshold = 0.0f;
                stratum.randSource01 = false;
                break;
            case 2:
                stratum.materialName = getRandomType(g_MetamorphicTypes);
                stratum.thickness = layerDepth(depth, gen);
                stratum.baseIntervall = 500.0f;
                stratum.octaves = 5;
                stratum.threshold = 0.0f;
                stratum.randSource01 = true;
                break;
            case 3:
            case 4:
                if(randTypeNum == 3) stratum.materialName = getRandomType(g_IntrusiveTypes);
                else stratum.materialName = "magma";
                import std.math : log;
                stratum.thickness = log(depth) * 4.0;
                //msg("Make plutonic intrusions have proper thickness");
                stratum.baseIntervall = 1000.0f;
                stratum.octaves = 3;
                stratum.threshold = 0.9f;
                stratum.randSource01 = true;
                break;
            default:
                msg(randTypeNum);
                BREAKPOINT;
        }
        if(randTypeNum != 4) {
            stratum.noise = new RandomType(seedFunc);
        }
        if(prevMaterial == stratum.materialName) continue;
        prevMaterial = stratum.materialName;
        stratum.depthStart = depth;
        strata ~= stratum;
        depth += stratum.thickness;
    }

    return strata;
}


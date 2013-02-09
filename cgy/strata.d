module strata;



import std.algorithm : min, max;

import util.util;
import random.valuesource;
import random.gradientnoise;
import random.simplex;

float pmin = 12931923123.0f;
float pmax = -12931923123.0f;

alias SimplexNoise RandomType;
//alias GradientNoise!() RandomType;

immutable awesomeSeed = 880128;
//alias awesomeSeed seedFunc;
alias unpredictableSeed seedFunc;

struct MaterialStratum {
    string materialName;
    float thickness;
    float baseIntervall;
    byte octaves;
    float threshold;
    bool randSource01;
    ValueSource noise;
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
                value += amplitude * (noise.getValue(pos.X, pos.Y) * 0.5f + 0.5f);
                amplitude *= 0.5;
                pos *= 2;
                frequency *= 2;
            }
            pmin = min(pmin, value);
            pmax = max(pmax, value);
            //msg("01: ", value, " ", pmin, " ", pmax);
            value = (value*0.4+0.8 - threshold) * thickness; //80% guaranteed, may reach 120%
        } else {
            amplitude = 0.5; //Max will be 1.0 then, minimum will be -1.0
            for(int iter = 0; iter < octaves; iter++) {
                value += amplitude * noise.getValue(pos.X, pos.Y);
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

import json;
import util.filesystem;
import std.path;


void loadStrataInfo() {

    loadJSON("data/layers/soils.json").read(g_SoilTypes);
    loadJSON("data/layers/sedimentary.json").read(g_SedimentaryTypes);
    loadJSON("data/layers/extrusive.json").read(g_ExtrusiveTypes);
    loadJSON("data/layers/metamorphic.json").read(g_MetamorphicTypes);
    loadJSON("data/layers/intrusive.json").read(g_IntrusiveTypes);
}

import std.random;
Random gen;
string prevMaterialName;

auto generateStratas() {


    immutable targetDepth = 5000.0f; //Lets say 2 kilometers worth of depth is enough for now! :p
    immutable averageThickness = 100.0f;
    immutable min = averageThickness - 75.0f;
    immutable max = averageThickness + 75.0f;
    immutable sedimentaryLimit = 1500.0f;

    gen.seed(awesomeSeed);

    static auto getRandomType(LayerInformation layer) {
        while(true) {
            auto id = uniform(0, layer.basicTypes.length, gen);
            auto selected = layer.basicTypes[id];
            if(selected != prevMaterialName) {
                prevMaterialName = selected;
                msg("Selected ", selected);
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
    foreach(i ; 0 .. soilLayers) {
        stratum.materialName = getRandomType(g_SoilTypes);
        stratum.thickness = soilLayerThickness;
        stratum.baseIntervall = (i+1) * 100;
        stratum.octaves = 3;
        stratum.threshold = 0.0f;
        stratum.randSource01 = true;
        stratum.noise = new RandomType(awesomeSeed);
        strata ~= stratum;
    }
    depth += soilLayers * soilLayerThickness;

    while(depth < targetDepth) {
        auto randTypeNum = uniform(0, 5, gen);
        switch(randTypeNum) {
            case 0:
                if(depth > sedimentaryLimit) continue;
                stratum.materialName = getRandomType(g_SedimentaryTypes);
                stratum.thickness = uniform(min, max, gen);
                stratum.baseIntervall = 1000.0f;
                stratum.octaves = 5;
                stratum.threshold = 0.0f;
                stratum.randSource01 = true;
                break;
            case 1:
                stratum.materialName = getRandomType(g_ExtrusiveTypes);
                stratum.thickness = uniform(min, max, gen);
                stratum.baseIntervall = 1000.0f;
                stratum.octaves = 2;
                stratum.threshold = 0.0f;
                stratum.randSource01 = false;
                break;
            case 2:
                stratum.materialName = getRandomType(g_MetamorphicTypes);
                stratum.thickness = uniform(min, max, gen);
                stratum.baseIntervall = 500.0f;
                stratum.octaves = 5;
                stratum.threshold = 0.0f;
                stratum.randSource01 = true;
                break;
            case 3:
            case 4:
                if(randTypeNum == 3) stratum.materialName = getRandomType(g_IntrusiveTypes);
                else stratum.materialName = "magma";
                stratum.thickness = uniform(min, max, gen);
                msg("Make plutonic intrusions have proper thickness");
                stratum.baseIntervall = 1000.0f;
                stratum.octaves = 5;
                stratum.threshold = 0.8f;
                stratum.randSource01 = true;
                break;
            default:
                msg(randTypeNum);
                BREAKPOINT;
        }
        if(randTypeNum != 4) {
            stratum.noise = new RandomType(awesomeSeed);
        }
        strata ~= stratum;
        depth += stratum.thickness;
    }

    return strata;
}


module strata;




import util.util;



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

auto generateStratas() {

    float depth = 0.0;

    float targetDepth = 300;

    gen.seed(cast(int)utime());

    static auto getRandomType(string[] source) {
        auto id = uniform(0, source.length, gen);
        return source[id];
    }

    /*
    while(depth < targetDepth) {
        while(true) {
            auto type = getRandomType();
            if(type is prevType) continue; //For funniness sake dont allow this
            if(type.minDepth > depth) continue;
            if(type.maxDepth < depth) continue;
            //Other checks to decide not to use a material
            if(!type.okAfter(prevType)) continue;

            prevType = type;
            auto layerDepth = uniform(type.minHeight, type.maxHeight, gen); //Heurr heurr?
            layers ~= StrataLayer(type, layerDepth);
            depth += layerDepth;
            break;
        }
    }
    return layers;
    */

    return [];
}


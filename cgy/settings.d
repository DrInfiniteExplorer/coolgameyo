

module settings;

import std.conv;
import std.file;
import std.stdio;

import json;
import util;

struct RenderSettings {
    static struct InnerRenderSettings {
        //Just user settings.
        bool disableVSync;
        bool mipLevelInterpolate; //Interpolate between mip-levels or not?
        bool textureInterpolate;  // pick nearest pixel or interpolate?
        float anisotropy = 0; //set to max of this(uservalue) and implementation limit sometime
        bool renderWireframe;
        bool renderInvalidTiles = false;
        /* Derp derp derp */

        int pixelsPerTile = 16;

        int windowWidth = 800;
        int windowHeight = 600;
    }
    InnerRenderSettings serializableSettings;
    alias serializableSettings this; //goer lookup i inner, som i detta scopet :D niice

    //Some opengl-implementation-dependant constants, gathered on renderer creation
    int maxTextureLayers;
    int maxTextureSize;
    
    double glVersion = 0;
    
}

shared RenderSettings renderSettings;

vec3f getTileCoords(uint tileNum){
    vec3i tmp;
    uint TilesPerTexDim = renderSettings.maxTextureSize / renderSettings.pixelsPerTile;
    tmp.X = tileNum % TilesPerTexDim;
    tmp.Y = (tileNum / TilesPerTexDim) % TilesPerTexDim;
    tmp.Z = tileNum / (TilesPerTexDim*TilesPerTexDim);        
    vec3f ret = util.convert!float(tmp);
    float tileScale = 1.f / to!float(TilesPerTexDim);    
    return ret * vec3f(tileScale, tileScale, 1.f);;
}
vec3f getTileCoordSize(){
    float inv = to!float(renderSettings.pixelsPerTile) / to!float(renderSettings.maxTextureSize);
    return vec3f(inv, inv, 0.f);
}


void loadSettings(){
    if(!std.file.exists("settings.json")){
        writeln("Could not load settings");
        return;
    }
    auto content = readText("settings.json");
    
    auto rootVal = json.parse(content);
    auto rsVal = rootVal["renderSettings"];
    json.update(&renderSettings.serializableSettings, rsVal);
    
}

void saveSettings(){
    json.Value[string] values;
    values["renderSettings"] = encode(renderSettings.serializableSettings);
    auto jsonRoot = json.Value(values);
    auto jsonString = to!string(jsonRoot);
    std.file.write("settings.json", jsonString);
}





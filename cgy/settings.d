

module settings;

import std.conv;
import std.file;
import std.stdio;

import json;

struct RenderSettings{
    //Some opengl-implementation-dependant constants, gathered on renderer creation
    int maxTextureLayers;
    int maxTextureSize;
    double glVersion;

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

RenderSettings renderSettings;


void loadSettings(){
    if(!std.file.exists("settings.json")){
        writeln("Could not load settings");
        return;
    }
    auto content = readText("settings.json");
    
    auto rootVal = json.parse(content);
    auto rsVal = rootVal["renderSettings"];
    json.update(&renderSettings, rsVal);
    
}

void saveSettings(){
    json.Value[string] values;
    values["renderSettings"] = encode(renderSettings);
    auto jsonRoot = json.Value(values);
    auto jsonString = to!string(jsonRoot);
    std.file.write("settings.json", jsonString);
}





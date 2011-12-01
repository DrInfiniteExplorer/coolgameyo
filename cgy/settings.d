

module settings;

import std.conv;
import std.file;
import std.stdio;

import json;
import util.util;

struct RenderSettings {
    static struct InnerRenderSettings {
        // Just user settings.
        bool enableVSync;
        bool mipLevelInterpolate = true; // Interpolate between mip-levels or not?
        bool textureInterpolate = false;  // pick nearest pixel or interpolate?
        float anisotropy = 1; // set to max of this(uservalue)
                              // and implementation limit sometime
        bool renderWireframe;
        bool renderInvalidTiles = false;
        int smoothSetting = 1; // 0 = flat, 1 = smooth + AO, 2 = smooth - AO
        /* Derp derp derp */

        int pixelsPerTile = 16;

        int windowWidth = 800;
        int windowHeight = 600;

        //When 0, dont raycast at all!
        int raycastPixelSkip = 3; //Says wether or not to raycast all pixels, or just 1/4 of them.
        
        float fieldOfView = 90.f;
        float aspectRatio = 4.f / 3.f; //Width per height
        float nearPlane = 0.45f;
        float farPlane = 1000.f;
    }
	
    InnerRenderSettings serializableSettings;
    alias serializableSettings this;

	// These settings are generated in the program, not from settings file
	
    // Some opengl-implementation-dependant constants,
    // gathered on renderer creation
    int maxTextureLayers;
    int maxTextureSize;

    int renderTrueWorld = 0;
    
    double glVersion = 0;
    
}

struct ControlSettings {
	static struct InnerControlSettings {
		float mouseSensitivityX = 1;
		float mouseSensitivityY = 1;
	}
	InnerControlSettings serializableSettings;
	alias serializableSettings this;
}

shared RenderSettings renderSettings;
shared ControlSettings controlSettings;

vec3f getTileCoords(uint tileNum){
    vec3i tmp;
    uint TilesPerTexDim = renderSettings.maxTextureSize / renderSettings.pixelsPerTile;
    tmp.X = tileNum % TilesPerTexDim;
    tmp.Y = (tileNum / TilesPerTexDim) % TilesPerTexDim;
    tmp.Z = tileNum / (TilesPerTexDim*TilesPerTexDim);        
    vec3f ret = util.util.convert!float(tmp);
    float tileScale = 1.f / to!float(TilesPerTexDim);    
    return ret * vec3f(tileScale, tileScale, 1.f);;
}
vec3f getTileCoordSize(){
    float inv = to!float(renderSettings.pixelsPerTile) / to!float(renderSettings.maxTextureSize);
    return vec3f(inv, inv, 0.f);
}


void loadSettings(){
    if(!std.file.exists("settings.json")){
        msg("Could not load settings");
        return;
    }
    auto content = readText("settings.json");
    
    auto rootVal = json.parse(content);
    if("renderSettings" in rootVal){
        auto rsVal = rootVal["renderSettings"];
        json.read(renderSettings.serializableSettings, rsVal);
    }
    if("controlSettings" in rootVal){
	    auto controlVal = rootVal["controlSettings"];
        json.read(controlSettings.serializableSettings, controlVal);
    }
}


void saveSettings(){
    json.Value[string] values;

    values["renderSettings"] = encode(renderSettings.serializableSettings);
	values["controlSettings"] = encode(controlSettings.serializableSettings);

    auto jsonRoot = json.Value(values);
    auto jsonString = to!string(jsonRoot);
	
	jsonString = json.prettyfyJSON(jsonString);
	
    std.file.write("settings.json", jsonString);
}

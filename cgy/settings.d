

module settings;

import std.conv;
import std.file;
import std.stdio;

import json;
import util.util;
import util.window;

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


        int windowWidth = 800;
        int windowHeight = 600;

        //When 0, dont raycast at all!
        int raycastPixelSkip = 3; //Says wether or not to raycast all pixels, or just 1/4 of them.
        
        float fieldOfView = 90f;
        float aspectRatio = 4.0f / 3.0f; //Width per height
        float nearPlane = 0.45f;
        float farPlane = 3000.0f;
    }

    InnerRenderSettings serializableSettings;
    alias serializableSettings this;

	// These settings are generated in the program, not from settings file
    double widthHeightRatio() shared @property {
        return cast(double)windowWidth / cast(double)windowHeight;
    }
	
    // Some opengl-implementation-dependant constants,
    // gathered on renderer creation
    int maxTextureLayers;
    int maxTextureSize;
    int pixelsPerTile = 32;

    int renderTrueWorld = 1;

    bool canUseFBO;
    
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

struct WindowSettings {
	static struct InnerWindowSettings {
        vec2i mainCoordinates = vec2i(-1);
        vec2i consoleCoordinates = vec2i(-1);
	}
	InnerWindowSettings serializableSettings;
	alias serializableSettings this;
    bool windowsInitialized = false;
}

shared RenderSettings renderSettings;
shared ControlSettings controlSettings;
shared WindowSettings windowSettings;

vec3f getTileCoords(uint tileNum){
    vec3i tmp;
    uint TilesPerTexDim = renderSettings.maxTextureSize / renderSettings.pixelsPerTile;
    tmp.x = tileNum % TilesPerTexDim;
    tmp.y = (tileNum / TilesPerTexDim) % TilesPerTexDim;
    tmp.z = tileNum / (TilesPerTexDim*TilesPerTexDim);        
    vec3f ret = tmp.convert!float();
    float tileScale = 1.0f / to!float(TilesPerTexDim);    
    return ret * vec3f(tileScale, tileScale, 1.0f);
}
vec3f getTileCoordSize(){
    float inv = to!float(renderSettings.pixelsPerTile) / to!float(renderSettings.maxTextureSize);
    return vec3f(inv, inv, 0.0f);
}

__gshared string g_settingsFilePath = "settings.json";

void loadSettings(){
    Value rootVal;
    
    if(!loadJSON(g_settingsFilePath, rootVal)) {
        msg("Assigned settings file could not be loaded. Trying default settings file.");
        if(!loadJSON("settings.json", rootVal)) {
            msg("Settings file does not exist.");
            return;
        }
    }

    rootVal.readJSONObject("renderSettings", &renderSettings.serializableSettings,
                           "controlSettings", &controlSettings.serializableSettings,
                           "windowSettings", &windowSettings.serializableSettings);
}


void saveSettings(){

    captureWindowPositions();
    makeJSONObject("renderSettings", renderSettings.serializableSettings,
                   "controlSettings", controlSettings.serializableSettings,
                   "windowSettings", windowSettings.serializableSettings).saveJSON(g_settingsFilePath);


}

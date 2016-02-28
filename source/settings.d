

module settings;

import std.conv;
import std.file;
import std.json;
import std.stdio;

//import derelict.sdl.sdl : SDL_WM_GrabInput, SDL_GRAB_ON, SDL_GRAB_OFF;

import painlessjson : toJSON;

import cgy.math.vector;

import cgy.util.json : loadJSON, unJSON;
import cgy.util.util;
import cgy.util.window;

// No need to make these shared, gshared works fine? IM A COWBOY

__gshared {
    RenderSettings renderSettings;
    ControlSettings controlSettings;
    WindowSettings windowSettings;
    string g_playerName = "BurntFaceMan"; //Default player name

    string g_settingsFilePath = "settings.json";
    string[] g_serverList;

    int g_maxThreadCount = 2;

    float dragScrollSpeed = 0.15f; // tiles per pixel moved
    float borderScrollSpeed = 10.0f; // tiles per second when mouse at border.
}

void loadSettings(){
    JSONValue rootVal;

    rootVal = loadJSON(g_settingsFilePath);
    rootVal = loadJSON("settings.json");

    g_serverList = null;
    msg(rootVal);

    rootVal["renderSettings"   ].unJSON(renderSettings.serializableSettings);
    rootVal["controlSettings"  ].unJSON(controlSettings.serializableSettings);
    rootVal["windowSettings"   ].unJSON(windowSettings.serializableSettings);
    rootVal["playerName"       ].unJSON(g_playerName);
    rootVal["serverList"       ].unJSON(g_serverList);
    rootVal["maxThreads"       ].unJSON(g_maxThreadCount);
    rootVal["dragScrollSpeed"  ].unJSON(dragScrollSpeed);
    rootVal["borderScrollSpeed"].unJSON(borderScrollSpeed);
}


void saveSettings(){

    captureWindowPositions(delegate(immutable cgy.windows.RECT mainRect, immutable cgy.windows.RECT consoleRect) {
        windowSettings.mainCoordinates.x = mainRect.left;
        windowSettings.mainCoordinates.y = mainRect.top;
        windowSettings.consoleCoordinates.x = consoleRect.left;
        windowSettings.consoleCoordinates.y = consoleRect.top;
    });

    auto str = JSONValue([
        "renderSettings" :    renderSettings.serializableSettings.toJSON,
        "controlSettings":   controlSettings.serializableSettings.toJSON,
        "windowSettings":     windowSettings.serializableSettings.toJSON,
        "playerName":                                g_playerName.toJSON,
        "serverList":                                g_serverList.toJSON,
        "maxThreads":                            g_maxThreadCount.toJSON,
        "dragScrollSpeed":                        dragScrollSpeed.toJSON,
        "borderScrollSpeed":                    borderScrollSpeed.toJSON,
    ]).toString;
    std.file.write(g_settingsFilePath, str);


}

void applyWindowSettings() {
    if(!windowSettings.windowsInitialized) return;
    cgy.windows.RECT mainRect  =   {left : windowSettings.consoleCoordinates.x, top : windowSettings.consoleCoordinates.y};
    cgy.windows.RECT consoleRect = {left : windowSettings.consoleCoordinates.x, top : windowSettings.consoleCoordinates.y};
    repositionWindows(mainRect, consoleRect);

    // Forces the mouse to be within the window
    msg("SDL_WM_GrabInput(windowSettings.trapMouse ? SDL_GRAB_ON : SDL_GRAB_OFF);");

}


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
    double widthHeightRatio() @property {
        return cast(double)windowWidth / cast(double)windowHeight;
    }
	
    // Some opengl-implementation-dependant constants,
    // gathered on renderer creation
    int maxTextureLayers;
    int maxTextureSize;
    int pixelsPerTile = 32;

    int renderTrueWorld = 1;

    bool canUseFBO;    
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
        bool trapMouse = false;
        bool windowed = true;
	}
	InnerWindowSettings serializableSettings;
	alias serializableSettings this;
    bool windowsInitialized = false;
}

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

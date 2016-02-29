

module main;

import core.memory;
import core.runtime;
import core.thread;
import core.stdc.stdlib;

import std.conv;
import std.concurrency;
import std.exception;
import std.getopt;
import std.stdio;
import std.string;
import std.typecons : scoped;

//pragma(lib, "derelictal.lib");
//pragma(lib, "derelictil.lib");
//pragma(lib, "derelictgl.lib");
//pragma(lib, "derelictutil.lib");
//pragma(lib, "derelictsdl.lib");

import derelict.openal.al;
import derelict.sdl2.sdl;
import derelict.opengl3.gl;
import derelict.devil.il;
import derelict.devil.ilu;

import alloc;
import globals;
import graphics.ogl;
import gui.guisystem.guisystem;
import gui.joinmenu;
import gui.mainmenu;
import gui.printscreenmenu;
import gui.random.randommenu;
import graphics.heightmap;
import gui.serverinterface;
import cgy.logger.log;

import materials;

import cgy.opengl.error : glError;
import cgy.debug_.debug_ : setThreadName;
import cgy.util.statistics;
import settings;
import cgy.util.filesystem;
import cgy.util.memory;
import cgy.util.pos;
import cgy.util.util;
import cgy.util.window;
import worldgen.maps : WorldSize;


import modelparser.cgyparser;

version (X86_64) {
    pragma (msg, "Compiling for 64 bit");
}
version (Windows) {
    pragma (msg, "Compiling for windows");
}


void initializePaths(){
    import std.file : getcwd, chdir, exists;
	import std.string : toStringz, toLower;
	import std.path : dirName, baseName;
    import std.conv : to;
    import cgy.windows : GetModuleFileNameA, SetDllDirectoryA;

    void setBin(string path)
    {
		char[512] exePath;
		auto len = GetModuleFileNameA(null, exePath.ptr, exePath.sizeof);
		exePath[len] = 0;
		auto binPath = exePath.to!string.dirName ~ path;
        SetDllDirectoryA(binPath.toStringz());
    }

    void enterGameRoot()
    {
		auto dirName = getcwd.dirName.baseName;
        if(dirName.toLower == "gameroot") return;
        if(exists("gameroot")) {
            chdir("gameroot");
        }
    }

    version(Win32) {
        setBin(r"\bin\x86\");
    }
    version(Win64) {
        setBin(r"\bin\x64\");
    }

    enterGameRoot();
}


__gshared SDL_Window* sdlWindow;

__gshared string[] g_commandLine;

void main(string[] args) {
    version(LDC) {
        try {
            main2(args);
        }
        catch(Exception e)
        {
            msg(e.to!string);
            BREAKPOINT;
        }
    }
    else
    {
        main2(args);
    }
}

void main2(string[] args) {
    initializePaths();
    g_commandLine = args.dup;

    bool materialEditor;
    bool randomMenu;
    bool splineEditor;
    string joinGame;
    string heightmap;
    //args ~= "--SplineEditor";

    getopt(g_commandLine,
            std.getopt.config.passThrough,
            "MaterialEditor", &materialEditor,
            "RandomMenu", &randomMenu,
            "SplineEditor", &splineEditor,
            "HeightMap", &heightmap,
            "settingsFile", &g_settingsFilePath,
            "playerName", &g_playerName,
            "hostGame", &g_worldPath,
            "joinGame", &joinGame);

    loadSettings();
    saveSettings();

    setThreadName("Main thread");
    std.concurrency.register("Main thread", thisTid());

    initLibraries();


    loadSettings();
    saveSettings();
    scope(exit) {
        saveSettings();
        deinitLibraries();
    }

    createWindow();

    init_temp_alloc(1024*1024);

    if (randomMenu) {
        displayRandomMenu();
    }

    if(splineEditor) {
        import gui.splineedit;
        displaySplineEditor();
    }
    if (heightmap) {
        displayHeightmap(heightmap);
    }

    if (materialEditor) {
        MaterialEditor();
    }

    if (g_worldPath) {
        rmdir("saves/server");
        copy("saves/" ~ g_worldPath, "saves/server");
        g_isServer = true;
        g_worldPath = "saves/server";
        startServer();
        return;
    }
    if (joinGame) {
        rmdir("saves/client");
        g_isServer = false;
        g_worldPath = "saves/client";
        startClient(joinGame);
        return;
    }
    string menu = "main";
    while(menu != "exit") {
        switch(menu) {
            case "main":
                menu = mainMenu();
                break;
            case "join":
                menu = joinMenu();
                break;
            case "host":
                //menu = hostMenu();
                startServer();
                break;
            default:
                LogError("Bad menu option:", menu);
                BREAKPOINT;
        }
    }
}

void initLibraries() {
	try {
		DerelictSDL2.load();
		DerelictGL3.load();
		DerelictIL.load();
		DerelictILU.load();
	//    DerelictAL.load();

		ilInit();
		iluInit();
	} catch (Exception e) {
		msg("Failed to load stuff");
		BREAKPOINT;
	}
}

void deinitLibraries() {
    //TODO: destroy "surface" and how? :P        
    deinitOpenGL();
    SDL_Quit();
//    DerelictAL.unload();
    DerelictIL.unload();
    DerelictGL3.unload();
    DerelictSDL2.unload();
}

void createWindow() {

	auto version_ = glGetString(GL_VERSION);
	auto vendor = glGetString(GL_VENDOR);
	auto renderer = glGetString(GL_RENDERER);

    std.exception.enforce(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_NOPARACHUTE) == 0,
                          SDL_GetError.to!string);

    SDL_GL_SetAttribute(SDL_GL_RED_SIZE,        8);
    SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE,      8);
    SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE,       8);
    SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE,      8);

//    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE,      32);
    SDL_GL_SetAttribute(SDL_GL_BUFFER_SIZE,     32);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER,      1);

//    //Smoothes the edges of the tiles, makes it look real nice
    SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS,  1);
    SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES,  16);

    auto surfaceMode = SDL_WINDOW_OPENGL;
    if(!windowSettings.windowed) {
        surfaceMode |= SDL_WINDOW_FULLSCREEN;
    }
    const(char)[] asd ="asd\0".dup;
    sdlWindow = SDL_CreateWindow("asd".toStringz,
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
                               renderSettings.windowWidth,
                               renderSettings.windowHeight,
                               surfaceMode
                               );
    enforce(sdlWindow, text("Could not set sdl video mode (", SDL_GetError.to!string , ")"));
    SDL_GL_CreateContext(sdlWindow);

    SDL_SysWMinfo info;
    SDL_VERSION(&info.version_);
    setMainWindow(info.info.win.window);

    windowSettings.windowsInitialized = true;
    applyWindowSettings();

    initOpenGL();
}

__gshared bool inputActive = true;
bool handleSDLEvent(in SDL_Event event, float now, GuiSystem guiSystem) {
    bool exit = false;
    switch (event.type){
        case SDL_WINDOWEVENT:
            if(event.window.event == SDL_WINDOWEVENT_FOCUS_GAINED) {
                inputActive = true;
            }else if(event.window.event == SDL_WINDOWEVENT_FOCUS_LOST) {
                inputActive = false;
            }

            /*
            // Manually resets the mouse within the window. Not as good as SDL_WM_GrabInput(SDL_GRAB_ON), which never lets the mouse out of the window.
            if(event.active.state & SDL_APPMOUSEFOCUS) {

                // If the mouse moves out of the window, we have input focus and we are within this
                // limit from the border, tell the engine the cursor is actually at the border.
                //Or... ?
                static immutable snapLimit = 16;
                if(event.active.gain == 0 && inputActive) {
                    int x, y;
                    SDL_GetMouseState(&x, &y);
                    //msg(" ", x, " ", y);
                    void set(int x, int y) {
                        SDL_WarpMouse(cast(ushort)x, cast(ushort)y);
                    }
                    if(x < snapLimit) {
                        set(0, y);
                    }
                    if(y < snapLimit) {
                        set(x, 0);
                    }
                    if(x >= renderSettings.windowWidth - snapLimit) {
                        set(renderSettings.windowWidth-1, y);
                    }
                    if(y >= renderSettings.windowHeight - snapLimit) {
                        set(x, renderSettings.windowHeight-1);
                    }
                }
            }
            */
            break;
        case SDL_KEYDOWN:
        case SDL_KEYUP:
        case SDL_MOUSEMOTION:
        case SDL_MOUSEBUTTONDOWN:
        case SDL_MOUSEBUTTONUP:
            if(!inputActive) return false;
            goto default;
        default:
    }
    switch (event.type) {
        case SDL_QUIT:
            exit = true;
            break;
        case SDL_KEYDOWN:
        case SDL_KEYUP:
            if(event.key.state == SDL_PRESSED && event.key.keysym.sym == SDLK_PRINTSCREEN) {
                PrintScreen();
            } else {
                auto kb = scoped!KeyboardEvent(now);
                kb.pressed = event.key.state == SDL_PRESSED;
                kb.repeat = 0; //TODO: Implement later?
                auto unicode = event.key.keysym.unicode;
                if (unicode & 0xFF80) { // Haha i dont know what this is about now. Prolly multi-byte keys? maybe? :D
                } else {
                    kb.ch = unicode & 0x7F;
                }
                kb.SdlSym = event.key.keysym.sym;
                kb.SdlMod = event.key.keysym.mod;

                guiSystem.onEvent(kb);
            }
            break;
        case SDL_MOUSEMOTION:
            auto m = scoped!MouseMove(now);
            m.pos.set(event.motion.x,
                      event.motion.y);
            m.delta.set(event.motion.xrel,
                        event.motion.yrel);
            guiSystem.onEvent(m);
            if(m.applyReposition) {
                SDL_WarpMouseInWindow(sdlWindow, cast(ushort)m.reposition.x, cast(ushort)m.reposition.y);
            }
            break;
        case SDL_MOUSEBUTTONDOWN:
        case SDL_MOUSEBUTTONUP:

            auto m = scoped!MouseClick(now);
            m.down = event.type == SDL_MOUSEBUTTONDOWN;
            m.left = event.button.button == SDL_BUTTON_LEFT;
            m.right = event.button.button == SDL_BUTTON_RIGHT;
            m.middle = event.button.button == SDL_BUTTON_MIDDLE;
            m.pos.set(event.button.x,
                      event.button.y);
            guiSystem.onEvent(m);                        
            break;
        case SDL_MOUSEWHEEL:
            auto m = scoped!MouseWheel(now);
            m.amount = event.wheel.y;
            guiSystem.onEvent(m);
            break;
        default:
    }

    version (Windows) {
        if (event.key.keysym.sym == SDLK_F4
            && (event.key.keysym.mod == KMOD_LALT
                || event.key.keysym.mod == KMOD_RALT)) {
                    exit=true;
                }
    }
    return exit;
}

// Returns true if SDL things its time to quit.
bool EventAndDrawLoop(bool canYield)(GuiSystem guiSystem, scope void delegate(float) render, scope bool delegate() endLoop = null) {
    long then = utime();
    long now = utime()+1;
    bool exit = false;
    bool exitLoop = false;
    SDL_Event event;
    while (!exitLoop) {
        while (SDL_PollEvent(&event)) {
            exit = handleSDLEvent(event, now / 1_000_000.0, guiSystem);
            exitLoop |= exit;

        }

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glError();

        now = utime();
        long diff = now-then;
        float deltaT = cast(float)diff / 1_000_000.0f;            
        then = now;

        if (render) {
            render(deltaT);
        }
        guiSystem.tick(deltaT); //Eventually add deltatime and such as well :)
        guiSystem.render();
        SDL_GL_SwapWindow(sdlWindow);
        if (endLoop) {
            exitLoop |= endLoop();
        }
        static if (canYield) {
            //Thread.yield();
            Thread.sleep(dur!"msecs"(1));
        }
    }
    return exit;
}



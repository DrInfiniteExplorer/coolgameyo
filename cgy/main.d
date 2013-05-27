

module main;

import core.memory;
import core.runtime;
import core.thread;

import std.c.stdlib;
import std.conv;
import std.concurrency;
import std.exception;
import std.getopt;
import std.stdio;
import std.string;

pragma(lib, "derelictal.lib");
pragma(lib, "derelictil.lib");
pragma(lib, "derelictgl.lib");
pragma(lib, "derelictutil.lib");
pragma(lib, "derelictsdl.lib");

import derelict.openal.al;
import derelict.sdl.sdl;
import derelict.opengl.gl;
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
import log;

import materials;

import statistics;
import settings;
import util.filesystem;
import util.memory;
import util.pos;
import util.util;
import util.window;
import worldgen.maps : WorldSize;


import modelparser.cgyparser;

version (X86_64) {
    pragma (msg, "Compiling for 64 bit");
}
version (Windows) {
    pragma (msg, "Compiling for windows");
}

__gshared SDL_Surface* surface;

__gshared string[] g_commandLine;

void main(string[] args) {
    g_commandLine = args.dup;

    bool materialEditor;
    bool randomMenu;
    string joinGame;
    string heightmap;

    getopt(args,
            std.getopt.config.passThrough,
            "MaterialEditor", &materialEditor,
            "RandomMenu", &randomMenu,
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

    scope(exit) {
        saveSettings();
        deinitLibraries();
    }

    createWindow();

    init_temp_alloc(1024*1024);

    if (randomMenu) {
        displayRandomMenu();
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
    DerelictSDL.load();
    DerelictGL.load();
    DerelictIL.load();
    DerelictILU.load();
//    DerelictAL.load();

    ilInit();
    iluInit();
}

void deinitLibraries() {
    //TODO: destroy "surface" and how? :P        
    deinitOpenGL();
    SDL_Quit();
//    DerelictAL.unload();
    DerelictIL.unload();
    DerelictGL.unload();
    DerelictSDL.unload();
}

void createWindow() {
    std.exception.enforce(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_NOPARACHUTE) == 0,
                          SDLError());

    SDL_GL_SetAttribute(SDL_GL_RED_SIZE,        8);
    SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE,      8);
    SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE,       8);
    SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE,      8);

    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE,      32);
    SDL_GL_SetAttribute(SDL_GL_BUFFER_SIZE,     32);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER,      1);

    //Smoothes the edges of the tiles, makes it look real nice
    SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS,  1);
    SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES,  16);

    surface = SDL_SetVideoMode(
                               renderSettings.windowWidth,
                               renderSettings.windowHeight,
                               32,
                               SDL_HWSURFACE | SDL_GL_DOUBLEBUFFER | SDL_OPENGL
                               );
    enforce(surface, text("Could not set sdl video mode (", SDLError() , ")"));
    windowSettings.windowsInitialized = true;
    repositionWindows();

    initOpenGL();

    SDL_EnableUNICODE(1);
    SDL_EnableKeyRepeat(SDL_DEFAULT_REPEAT_DELAY, SDL_DEFAULT_REPEAT_INTERVAL);
}

__gshared bool inputActive = true;
bool handleSDLEvent(in SDL_Event event, float now, GuiSystem guiSystem) {
    GuiEvent guiEvent;
    guiEvent.eventTimeStamp = now;
    bool exit = false;
    switch (event.type){
        case SDL_ACTIVEEVENT:
            if(event.active.state & SDL_APPINPUTFOCUS) {
                inputActive = event.active.gain != 0;
            }
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
            if(event.key.state == SDL_PRESSED && event.key.keysym.sym == SDLK_PRINT) {
                PrintScreen();
            } else {
                guiEvent.type = GuiEventType.Keyboard;
                auto kb = &guiEvent.keyboardEvent;
                kb.pressed = event.key.state == SDL_PRESSED;
                kb.repeat = 0; //TODO: Implement later?
                auto unicode = event.key.keysym.unicode;
                if (unicode & 0xFF80) { // Haha i dont know what this is about now. Prolly multi-byte keys? maybe? :D
                } else {
                    kb.ch = unicode & 0x7F;
                }
                kb.SdlSym = event.key.keysym.sym;
                kb.SdlMod = event.key.keysym.mod;

                guiSystem.onEvent(guiEvent);
            }
            break;
        case SDL_MOUSEMOTION:
            guiEvent.type = GuiEventType.MouseMove;
            auto m = &guiEvent.mouseMove;
            m.pos.set(event.motion.x,
                      event.motion.y);
            m.delta.set(event.motion.xrel,
                        event.motion.yrel);
            guiSystem.onEvent(guiEvent);
            break;
        case SDL_MOUSEBUTTONDOWN:
        case SDL_MOUSEBUTTONUP:
            guiEvent.type = GuiEventType.MouseClick;
            auto m = &guiEvent.mouseClick;
            m.down = event.type == SDL_MOUSEBUTTONDOWN;
            m.left = event.button.button == SDL_BUTTON_LEFT;
            m.right = event.button.button == SDL_BUTTON_RIGHT;
            m.middle = event.button.button == SDL_BUTTON_MIDDLE;
            m.wheelUp = event.button.button == SDL_BUTTON_WHEELUP;
            m.wheelDown = event.button.button == SDL_BUTTON_WHEELDOWN;
            m.pos.set(event.button.x,
                      event.button.y);
            guiSystem.onEvent(guiEvent);                        
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

void EventAndDrawLoop(bool canYield)(GuiSystem guiSystem, scope void delegate(float) render, scope bool delegate() endLoop = null) {
    long then;
    long now = utime();
    bool exit = false;
    SDL_Event event;
    while (!exit) {
        while (SDL_PollEvent(&event)) {
            exit = handleSDLEvent(event, now / 1_000_000.0, guiSystem);
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
        SDL_GL_SwapBuffers();
        if (endLoop) {
            exit = endLoop();
        }
        static if (canYield) {
            //Thread.yield();
            Thread.sleep(dur!"msecs"(1));
        }
    }
}



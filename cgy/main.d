

module main;

import core.memory;
import core.runtime;
import core.thread;

import std.c.stdlib;
import std.conv;
import std.concurrency;
import std.exception;
import std.stdio;
import std.string;

import std.file;

import derelict.sdl.sdl;
import derelict.opengl.gl;
import derelict.devil.il;
import derelict.devil.ilu;

import win32.windows;

import graphics.ogl;


import gui.guisystem.guisystem;

import game;

import util.pos;
import statistics;
import settings;
import util.memory;
import util.util;
import util.window;
import worldgen.maps;
import worldgen.maps : worldSize;


import modelparser.cgyparser;
import gui.mainmenu;

import alloc;

bool client = true;
bool server = true;
bool worker = true;
SDL_Surface* surface;     

void main(string[] args) {

    try {
        setThreadName("Main thread");
        std.concurrency.register("Main thread", thisTid());
        loadSettings();
        saveSettings();

        initLibraries();
        createWindow();

        init_temp_alloc(1024*1024);

        import heightmap;
        immutable mil = 10_000;
        new Heightmaps(1 * mil);
        
        //args ~= "MaterialEditor";

        bool doneSomething = false;
        foreach(arg ; args) {
            if(doneSomething) break;
            switch(arg) {
                case "MaterialEditor":
                    import materials;
                    MaterialEditor(); doneSomething = true; break;
                default:
            }
        }
        if(!doneSomething) {
            mainMenu();
        }

        saveSettings();
        deinitLibraries();
    } catch (Exception e) {
        import util.util;
        writeln("Exception:\n\n", e.msg);
        NativeDialogBox("Exception:\n\n" ~ e.msg, "Exception", NDBAnswer.Ok);
    }

}

void initLibraries() {
    DerelictSDL.load();
    if (client) {
        DerelictGL.load(); //Init opengl regardless?
    }
    DerelictIL.load();
    DerelictILU.load();
    ilInit();
    iluInit();
}

void deinitLibraries() {
    //TODO: destroy "surface" and how? :P        
    deinitOpenGL();
    SDL_Quit();
    DerelictIL.unload();
    if (client) {
        DerelictGL.unload();
    }
    DerelictSDL.unload();
}

void createWindow() {
    std.exception.enforce(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_NOPARACHUTE) == 0,
                          SDLError());

    if (client) {
        //Initialize opengl only if client... ?
        //Prolly want to otherwise as well, or gui wont work :P:P:P
        //But make less demanding settings in that case, etc.
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
    }

    surface = SDL_SetVideoMode(
                               renderSettings.windowWidth,
                               renderSettings.windowHeight,
                               32,
                               SDL_HWSURFACE | SDL_GL_DOUBLEBUFFER | SDL_OPENGL
                               );
    windowSettings.windowsInitialized = true;
    repositionWindows();
    enforce(surface, text("Could not set sdl video mode (" , SDLError() , ")"));                            
    initOpenGL(client);

    //Durnt remember what this actually did.. think this enables translation of keypresses to characters? :)
    SDL_EnableUNICODE(1);
    SDL_EnableKeyRepeat(SDL_DEFAULT_REPEAT_DELAY, SDL_DEFAULT_REPEAT_INTERVAL);
}

bool inputActive = true;
bool handleSDLEvent(in SDL_Event event, out GuiEvent guiEvent, GuiSystem guiSystem) {
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
            //onKey(event.key);
            break;
        case SDL_MOUSEMOTION:
            //mouseMove(event.motion);
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

void mainMenu() {
    GuiSystem guiSystem;
    MainMenu mainMenu;

    guiSystem = new GuiSystem;
    mainMenu = new MainMenu(guiSystem);
    import gui.random.randommenu;
    new RandomMenu(mainMenu);


    // Main loop etc
    long then;
    long now, nextTime = utime();
    bool exit = false;
    SDL_Event event;
    GuiEvent guiEvent;
    while (!exit) {
        while (SDL_PollEvent(&event)) {
            guiEvent.eventTimeStamp = now / 1_000_000.0;
            exit = handleSDLEvent(event, guiEvent, guiSystem);
        } //Out of sdl-messages
        exit |= mainMenu.done;

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glError();

        now = utime();
        long diff = now-then;
        float deltaT = to!float(diff) / 1_000_000.0f;            
        then = now;

        guiSystem.tick(deltaT); //Eventually add deltatime and such as well :)
        guiSystem.render();            

        SDL_GL_SwapBuffers();

        SDL_WM_SetCaption( "CoolGameYo!\0", "CoolGameYo!\0");
    }

    guiSystem.destroy();

    if(mainMenu.server) {
        startServer();
    } else {
        startClient(mainMenu.host);
    }
}
/*
Game startGame(vec2i startPos, string worldName, void delegate() loadDone) {
    assert(gameInstance is null, "We already had a game, lawl");
    mixin(LogTime!("StartupTime"));
    gameInstance = new Game(client, server, worker);
    gameInstance.newGame(startPos, worldName, loadDone);
    return gameInstance;
}
Game loadGame(string worldName, void delegate() loadDone) {
    assert(gameInstance is null, "We already had a game, lawl");
    mixin(LogTime!("StartupTime"));
    gameInstance = new Game(client, server, worker);
    gameInstance.loadGame(worldName, loadDone);
    return gameInstance;
}
*/



void startServer() {
    if(!exists("saves/current")) {
        return;
    }

    GuiSystem guiSystem;
    guiSystem = new GuiSystem;

    Game game = new Game(true);
    game.loadGame();

    // Main loop etc
    long then;
    long now, nextTime = utime();
    bool exit = false;
    SDL_Event event;
    GuiEvent guiEvent;
    while (!exit) {
        while (SDL_PollEvent(&event)) {
            guiEvent.eventTimeStamp = now / 1_000_000.0;
            exit = handleSDLEvent(event, guiEvent, guiSystem);
        } //Out of sdl-messages

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glError();

        now = utime();
        long diff = now-then;
        float deltaT = to!float(diff) / 1_000_000.0f;            
        then = now;

        guiSystem.tick(deltaT); //Eventually add deltatime and such as well :)
        guiSystem.render();            

        SDL_GL_SwapBuffers();

        SDL_WM_SetCaption( "CoolGameYo!\0", "CoolGameYo!\0");
    }

    game.destroy();
    guiSystem.destroy();

}


void startClient(string host) {

}

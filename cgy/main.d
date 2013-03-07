

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

import derelict.sdl.sdl;
import derelict.opengl.gl;
import derelict.devil.il;
import derelict.devil.ilu;

import win32.windows;

import graphics.ogl;


import gui.guisystem.guisystem;

import game;
import log;

import util.pos;
import statistics;
import settings;
import util.filesystem;
import util.memory;
import util.util;
import util.window;
import worldgen.maps;
import worldgen.maps : worldSize;


import modelparser.cgyparser;
import gui.mainmenu;

import alloc;

SDL_Surface* surface;     

void testAdvect() {
    import graphics.image;
    import math.math;
    Image Img = Image("climateMap_name.bmp");
    vec2f[] forceField;
    vec3f[] img;
    vec3f[] imgTo;
    forceField.length = 500^^2;
    img.length = 500^^2;
    imgTo.length = 500^^2;

    import util.rangefromto : Range2D;
    foreach(x, y ; Range2D(0, 500, 0, 500)) {
        img[x + y * 500] = Img.getPixel(x, y) * 255;
        auto toCenter = vec2f(250, 250) - vec2f(x, y);
        auto len = toCenter.getLength;
        import std.math : PI;
        toCenter.setLength(len * 2 * PI * 0.01);
        toCenter.set(-toCenter.y, toCenter.x);
        forceField[x + y * 500] = toCenter;
    }

    import random.xinterpolate;
    vec2f getForce(int x, int y) {
        if(x < 0 || y < 0 || x >= 500 || y >= 500) return vec2f(0);
        return forceField[x + y * 500];
    }
    auto get(int x, int y) {
        x = cast(int)clamp(x, 0, 499);
        y = cast(int)clamp(y, 0, 499);
        return img[x + y * 500];
    }
    void set(int x, int y, vec3f c) {
        imgTo[x + y * 500] = c;
    }
    import random.random;
    import std.conv : to;
    alias XInterpolate2!(lerp, getForce, vec2f) getF;
    alias XInterpolate2!(lerp, get, vec2f) getC;

    rmdir("advectTest");
    mkdir("advectTest");
    foreach(iter ; 0 .. 100) {
        advect(&getF, &getC, &set, 500, 500, 1.0);
        import std.algorithm;
        swap(img, imgTo);
        foreach(x, y ; Range2D(0, 500, 0, 500)) {
            Img.setPixel(x, y, img[x + y * 500].toColorUInt);
        }
        import util.filesystem;
        string name = "advectTest//";
        if(iter < 10) name ~= "00";
        else if(iter < 100) name ~= "0";
        name ~= to!string(iter) ~ ".bmp";
        Img.save(name);

    }


}

__gshared string[] g_commandLine;

void main(string[] args) {

    args ~= "--HeightMap=saves/880128/map/map1";
    args ~= "--HeightMapType=float";

    /*
    g_commandLine.length = args.length;
    foreach(i ; 0 .. args.length) {
        g_commandLine[i] = args[i];
    }
    */
    g_commandLine = args.dup;

    try {
        setThreadName("Main thread");
        std.concurrency.register("Main thread", thisTid());

        //args ~= "--MaterialEditor";
        //args ~= "--hostServer=880128";


        bool materialEditor;
        string joinGame;
        string heightmap;
        getopt(args,
               std.getopt.config.passThrough,
               "MaterialEditor", &materialEditor,
               "HeightMap", &heightmap,
               "settingsFile", &g_settingsFilePath,
               "hostGame", &g_worldPath,
               "joinGame", &joinGame);

        loadSettings();
        saveSettings();

        initLibraries();
        scope(exit) {
            saveSettings();
            deinitLibraries();
        }

        createWindow();

        //testAdvect();


        init_temp_alloc(1024*1024);

        if(heightmap) {
            import graphics.heightmap;
            displayHeightmap(heightmap);
        }

        if(materialEditor) {
            import materials;
            MaterialEditor();
        }
        if(g_worldPath) {
            rmdir("saves/server");
            copy("saves/" ~ g_worldPath, "saves/server");
            g_isServer = true;
            g_worldPath = "saves/server";
            startServer();
            return;
        }
        if(joinGame) {
            rmdir("saves/client");
            g_isServer = false;
            g_worldPath = "saves/client";
            startClient(joinGame);
            return;
        }

        mainMenu();
    } catch (Exception e) {
        import util.util;
        writeln("Exception:\n\n", e.msg);
        NativeDialogBox("Exception:\n\n" ~ e.msg, "Exception", NDBAnswer.Ok);
    }

}

void initLibraries() {
    DerelictSDL.load();
    DerelictGL.load(); //Init opengl regardless?
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
    DerelictGL.unload();
    DerelictSDL.unload();
}

void createWindow() {
    std.exception.enforce(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_NOPARACHUTE) == 0,
                          SDLError());

    //if (client) {
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
    //}

    surface = SDL_SetVideoMode(
                               renderSettings.windowWidth,
                               renderSettings.windowHeight,
                               32,
                               SDL_HWSURFACE | SDL_GL_DOUBLEBUFFER | SDL_OPENGL
                               );
    windowSettings.windowsInitialized = true;
    repositionWindows();
    enforce(surface, text("Could not set sdl video mode (" , SDLError() , ")"));                            
    initOpenGL();

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

    while(true) {
        GuiSystem guiSystem;
        MainMenu mainMenu;

        guiSystem = new GuiSystem;
        mainMenu = new MainMenu(guiSystem);
        import gui.random.randommenu;
        //new RandomMenu(mainMenu);


        // Main loop etc
        long then;
        long now, nextTime = utime();
        bool exit = false;
        SDL_Event event;
        GuiEvent guiEvent;
        while (!mainMenu.done) {
            while (SDL_PollEvent(&event)) {
                guiEvent.eventTimeStamp = now / 1_000_000.0;
                if(handleSDLEvent(event, guiEvent, guiSystem)) {
                    return;
                }
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
        guiSystem.destroy();

        if(mainMenu.server) {
            startServer();
            return;
        } else {
            if(!startClient(mainMenu.host)) {
                return;
            }
        }
    }
}

void startServer() {

    if(!exists(g_worldPath)) {
        msg("Alert! Tried to main.d:startServer() without a " ~ g_worldPath ~ "!");
        return;
    }

    GuiSystem guiSystem;
    guiSystem = new GuiSystem;

    string fullText = "Server log\n";
    import gui.guisystem.text;
    auto txt = new GuiElementText(guiSystem, vec2d(0), fullText);
    auto handleMsg = (string s) {
        synchronized(txt) {
            fullText ~= s;
            txt.setText(fullText);
        }
    };
    logCallback = handleMsg;

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


//Return true to return to main menu.
bool startClient(string host) {
    msg("Starting client...");
    if(exists(g_worldPath)) {
        msg("Alert! Old client stuff lingering; EXTERMINATING");
        rmdir(g_worldPath);
    }

    //Yes yes...
    GuiSystem guiSystem;
    guiSystem = new GuiSystem;
 
    bool exit = false;
    Game game = new Game(false);
    try {
        game.connect(host);
    } catch(Exception e) {
        import gui.guisystem.dialogbox;
        new DialogBox(guiSystem, "An error occured", e.msg,
                      "Ok", { exit = true; });
    }

    import gui.ingame;
    auto ingameGui = new InGameGui(guiSystem, game);

    scope(exit) {
        game.destroy();
        guiSystem.destroy();
    }

    // Main loop etc
    long then;
    long now, nextTime = utime();
    SDL_Event event;
    GuiEvent guiEvent;
    while (!exit) {
        while (SDL_PollEvent(&event)) {
            guiEvent.eventTimeStamp = now / 1_000_000.0;
            if(handleSDLEvent(event, guiEvent, guiSystem)) {
                return false;
            }
        } //Out of sdl-messages

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glError();

        now = utime();
        long diff = now-then;
        float deltaT = to!float(diff) / 1_000_000.0f;            
        then = now;

        guiSystem.tick(deltaT); //Eventually add deltatime and such as well :)
        guiSystem.render();

        game.render(diff);

        SDL_GL_SwapBuffers();

        SDL_WM_SetCaption( "CoolGameYo!\0", "CoolGameYo!\0");
    }
    return true;

}



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

import derelict.sdl.sdl;
import derelict.opengl.gl;
import derelict.devil.il;

import graphics.ogl;

import gui.guisystem.guisystem;

import game;
import util;
import pos;
import statistics;
import settings;
import worldgen.worldgen;

version (Windows) {
import std.c.windows.windows;

    extern (Windows) int WinMain(HINSTANCE hInstance,
            HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
        int result;

        void exceptionHandler(Throwable e)
        {
            MessageBoxA(null, e.toString().toStringz(),
                    "Error1", MB_OK | MB_ICONEXCLAMATION);
            throw e;
        }

        try
        {
            Runtime.initialize(&exceptionHandler);

            result = myWinMain(hInstance, hPrevInstance, lpCmdLine, nCmdShow);

            exit(0); //TODO: Fix. If not here, we get bad and sad memory errors the following line :(
            Runtime.terminate(&exceptionHandler);
        }
        catch (Throwable o) // catch any uncaught exceptions
        {
            version (NoMessageBox) {
                write(o, "\n\nderp: ");
                readln();
            } else {
                MessageBoxA(null, o.toString().toStringz(),
                        "Error2", MB_OK | MB_ICONEXCLAMATION);
            }
            result = 0; // failed
        }
        return result;
    }

    int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
    {
        actualMain();
        return 0;
    }
} else {
    void main() {
        actualMain();
    }
}

import gui.mainmenu;

class Main {
    GuiSystem guiSystem;
    Game game;
    SDL_Surface* surface;     
    
    MainMenu mainMenu;
    
    bool client, server, worker;
    
    this(bool c, bool s, bool w) {
        client = c;
        server = s;
        worker = w;
        setThreadName("Main thread");
        std.concurrency.register("Main thread", thisTid());
        loadSettings();
        saveSettings();
        
        initLibraries();
        
        createWindow();
        mainMenu = new MainMenu(guiSystem, this);
    }
    
    void destroy() {
        if (game !is null) {
            game.destroy();
            game = null;
        }
        deinitLibraries();
    }
    
    void createWindow() {
        enforce(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_NOPARACHUTE) == 0,
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
        enforce(surface, text("Could not set sdl video mode (" , SDLError() , ")"));                            
        initOpenGL(client);
        
        //Durnt remember what this actually did.. think this enables translation of keypresses to characters? :)
        SDL_EnableUNICODE(1);
        SDL_EnableKeyRepeat(SDL_DEFAULT_REPEAT_DELAY, SDL_DEFAULT_REPEAT_INTERVAL);
        
        guiSystem = new GuiSystem;
        
    }
    
    Game startGame(void delegate() loadDone) {
		assert(game is null, "We already had a game, lawl");
        mixin(LogTime!("StartupTime"));
        game = new Game(client, server, worker);
        WorldGenParams worldParams;
        game.newGame(worldParams, loadDone);
        return game;
    }
    
    void loadDone() {
        game.loadDone();
    }
    
    bool inputActive = true;
    long then;
    void run() {
        auto exit = false;
        SDL_Event event;
        GuiEvent guiEvent;
        while (!exit) {
            while (SDL_PollEvent(&event)) {
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
                        if(!inputActive) continue;
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
                        if (unicode & 0xFF80) {
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
                        guiSystem.onEvent(guiEvent);
                        break;
                    case SDL_MOUSEBUTTONDOWN:
                    case SDL_MOUSEBUTTONUP:
                        guiEvent.type = GuiEventType.MouseClick;
                        auto m = &guiEvent.mouseClick;
                        m.down = event.type == SDL_MOUSEBUTTONDOWN;
                        m.left = event.button.button == SDL_BUTTON_LEFT; //Makes all others right. including scrollwheel, i think. :P
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
            }
            
            receiveTimeout(0, 
                (string msg) { if(msg == "finishInit") { loadDone();}}
            );

            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            glError();
            
            if(game) {
                game.render();
            }
            long now = utime();
            float deltaT = (now-then) / 100_000.f;
            then = now;
            guiSystem.tick(deltaT); //Eventually add deltatime and such as well :)
            guiSystem.render();            
            
            SDL_GL_SwapBuffers();
        }
        msg("Main thread got exited? :S");
        BREAKPOINT(!exit);        
    }
    
    void initLibraries() {
        DerelictSDL.load();
        if (client) {
            DerelictGL.load(); //Init opengl regardless?
        }
        DerelictIL.load();
        ilInit();
    }
    
    void deinitLibraries() {
        //TODO: destroy "surface" and how? :P        
        SDL_Quit();
        DerelictIL.unload();
        if (client) {
            DerelictGL.unload();
        }
        DerelictSDL.unload();
    }
}

import world;
void actualMain() {

    
    
    version (Windows) {
        bool client = true;
    } else {
        // plols laptop cant handle the CLIENT STUFF WHOOOOAAhhhh....!!
        bool client = false;
    }
    
    Main main = new Main(client, true, true); //Be a worker? lolololol
    main.run();
    main.destroy();    
}


module main;


import core.memory;
import core.runtime;
import core.thread;
import std.stdio;
import std.string : toStringz;
import std.c.stdlib;

import derelict.sdl.sdl;
import derelict.opengl.gl;
import derelict.devil.il;

import game;
import util;
import pos;
import settings;

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

            //These lines do nothing to remedy the problem below =/
            GC.collect();
            GC.collect();
            GC.collect();
            GC.collect();
            GC.collect();
            GC.collect();
            GC.collect();
            GC.collect();
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

import world;
void actualMain() {

    setThreadName("Main thread");
    
    loadSettings();
    saveSettings();
    
    version (Windows) {
        bool client = true;
    } else {
        // plols laptop cant handle the CLIENT STUFF WHOOOOAAhhhh....!!
        bool client = false;
    }
    if (client) {
        writeln("Loading libraries...");
        scope (success) writeln("... done");
        DerelictSDL.load();
        DerelictGL.load();
        DerelictIL.load();
        ilInit();
    }
    scope (exit) if (client) {
        SDL_Quit();
        DerelictIL.unload();
        DerelictGL.unload();
        DerelictSDL.unload();
    }

    writeln("Creating game");
    auto game = new Game(true, client, true);
    writeln("Starting game");
    game.start();
    writeln("Game now officially ended!");
}


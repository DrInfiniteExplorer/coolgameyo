module main;

import core.runtime;
import core.thread;
import std.stdio;
import std.string : toStringz;

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
            throw e;
        }

        try
        {
            Runtime.initialize(&exceptionHandler);

            result = myWinMain(hInstance, hPrevInstance, lpCmdLine, nCmdShow);

            Runtime.terminate(&exceptionHandler);
        }
        catch (Throwable o) // catch any uncaught exceptions
        {
            version (NoMessageBox) {
                write(o, "\n\nderp: ");
                readln();
            } else {
                MessageBoxA(null, o.toString().toStringz(),
                        "Error", MB_OK | MB_ICONEXCLAMATION);
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
}


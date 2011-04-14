module main;

import core.runtime;
import std.stdio;

import derelict.sdl.sdl;
import derelict.opengl.gl;
import derelict.devil.il;

import game;
import util;
import pos;

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
            MessageBoxA(null, cast(char *)o.toString(), 
                    "Error", MB_OK | MB_ICONEXCLAMATION);
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
    auto a = tilePos(vec3i(1,2,3));
    writeln(a);
    
    version (Windows) {
        bool client = true;
    } else {
        // plols laptop cant handle the CLIENT STUFF WHOOOOAAhhhh....!!
        bool client = false;
    }
    if (client) {
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
    
    auto game = new Game(true, client, true);
    game.start();
}


module main;

import core.runtime;
import std.c.windows.windows;
import std.stdio;

//import engine.irrlicht;

import win32.windows : ExitProcess;

import game;
import util;


/*
int main(string[] argv)
{
    Game game = new Game(true, true, true);
    game.run();

	return 0;
}
//*/

//*
extern (Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
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
    catch (Throwable o)		// catch any uncaught exceptions
    {
        MessageBoxA(null, cast(char *)o.toString(), "Error", MB_OK | MB_ICONEXCLAMATION);
        result = 0;		// failed
    }
    return result;
}

int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    Game game = new Game(true, true, true);
    game.run();
    //delete game;

    ExitProcess(0); //PREVENT GARBAGE COLLECTION AND FUKKEN ANOYING EXCEPTIONNSNSNSS!!!
    
    return 0;
}

//*/
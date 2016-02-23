module util.window;

import std.string;

//import derelict.sdl2.sdl;
import derelict.sdl2.sdl;


import settings;
import util.util;


version(Windows) {
    import windows;
}


version(Windows) {

    __gshared HWND __mainHwnd;
    void setMainWindow(HWND wnd)
    {
        __mainHwnd =wnd;
    }

    HWND getMainWindow() {
        return __mainHwnd;
    }

    void captureWindowPositions() {
        if(!windowSettings.windowsInitialized) return;
        RECT rect;
        GetWindowRect(__mainHwnd, &rect);
        windowSettings.mainCoordinates.x = rect.left;
        windowSettings.mainCoordinates.y = rect.top;

        auto consoleHwnd = GetConsoleWindow();
        GetWindowRect(consoleHwnd, &rect);
        windowSettings.consoleCoordinates.x = rect.left;
        windowSettings.consoleCoordinates.y = rect.top;
    }


    void repositionWindows() {
        if(!windowSettings.windowsInitialized) return;
        int x;
        int y;
        x = windowSettings.mainCoordinates.x;
        y = windowSettings.mainCoordinates.y;

        if(x != -1 || y != -1) {
            RECT rect;
            GetWindowRect(__mainHwnd, &rect);
            auto width = rect.right - rect.left;
            auto height = rect.bottom - rect.top;
            MoveWindow(__mainHwnd, x, y, width, height, true);
        }
        x = windowSettings.consoleCoordinates.x;
        y = windowSettings.consoleCoordinates.y;
        if(x != -1 || y != -1) {
            auto consoleHwnd = GetConsoleWindow();
            RECT rect;
            GetWindowRect(consoleHwnd, &rect);
            auto width = rect.right - rect.left;
            auto height = rect.bottom - rect.top;
            MoveWindow(consoleHwnd, x, y, width, height, true);
        }
    }
}


module util.window;

import std.string;

import derelict.sdl.sdl;


import settings;
import util.util;


version(Windows) {
    import win32.windows;

    HWND getMainWindow() {
        auto wierd_str = "I_am_a_flying_unicorn_who_farts_glitter";
        auto strZ = wierd_str.toStringz();
        SDL_WM_SetCaption(strZ, "derp");
        auto mainHwnd = FindWindow(null, strZ);
        BREAK_IF(mainHwnd == null);
        SDL_WM_SetCaption("CoolGameYo!", "Herp");
        return mainHwnd;
    }

    void captureWindowPositions() {
        if(!windowSettings.windowsInitialized) return;
        auto wierd_str = "I_am_a_flying_unicorn_who_farts_glitter";
        auto strZ = wierd_str.toStringz();
        RECT rect;
        SDL_WM_SetCaption(strZ, "derp");
        auto mainHwnd = FindWindow(null, strZ);
        BREAK_IF(mainHwnd == null);
        GetWindowRect(mainHwnd, &rect);
        windowSettings.mainCoordinates.X = rect.left;
        windowSettings.mainCoordinates.Y = rect.top;

        auto consoleHwnd = GetConsoleWindow();
        GetWindowRect(consoleHwnd, &rect);
        windowSettings.consoleCoordinates.X = rect.left;
        windowSettings.consoleCoordinates.Y = rect.top;

        SDL_WM_SetCaption("CoolGameYo!", "Herp");
    }


    void repositionWindows() {
        if(!windowSettings.windowsInitialized) return;
        int x;
        int y;
        x = windowSettings.mainCoordinates.X;
        y = windowSettings.mainCoordinates.Y;

        if(x != -1 || y != -1) {
            auto wierd_str = "I_am_a_flying_unicorn_who_farts_glitter";
            auto strZ = wierd_str.toStringz();
            RECT rect;
            SDL_WM_SetCaption(strZ, "derp");
            auto mainHwnd = FindWindow(null, strZ);
            BREAK_IF(mainHwnd == null);
            GetWindowRect(mainHwnd, &rect);
            auto width = rect.right - rect.left;
            auto height = rect.bottom - rect.top;
            MoveWindow(mainHwnd, x, y, width, height, true);
            SDL_WM_SetCaption("CoolGameYo!", "Herp");
        }
        x = windowSettings.consoleCoordinates.X;
        y = windowSettings.consoleCoordinates.Y;
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


module cgy.util.window;

import std.string;


//import cgy.util.util;


version(Windows) {
    import cgy.windows;
}


version(Windows) {

    __gshared HWND __mainHwnd = null;
    void setMainWindow(HWND wnd)
    {
        __mainHwnd =wnd;
    }

    HWND getMainWindow() {
        return __mainHwnd;
    }

    void captureWindowPositions(scope void delegate(immutable RECT mainRect, immutable RECT consoleRect) cb) {
        if(__mainHwnd is null) return;
        RECT mainRect;
        GetWindowRect(__mainHwnd, &mainRect);

        auto consoleHwnd = GetConsoleWindow();
        RECT consoleRect;
        GetWindowRect(consoleHwnd, &consoleRect);
        cb(mainRect, consoleRect);
    }


    void repositionWindows(RECT mainRect, RECT consoleRect) {
        if(__mainHwnd is null) return;

        if(mainRect.left != -1 || mainRect.top != -1) {
            GetWindowRect(__mainHwnd, &mainRect);
            auto width = mainRect.right - mainRect.left;
            auto height = mainRect.bottom - mainRect.top;
            MoveWindow(__mainHwnd, mainRect.left, mainRect.top, width, height, true);
        }
        if(consoleRect.left != -1 || consoleRect.top != -1) {
            auto consoleHwnd = GetConsoleWindow();
            GetWindowRect(consoleHwnd, &consoleRect);
            auto width = consoleRect.right - consoleRect.left;
            auto height = consoleRect.bottom - consoleRect.top;
            MoveWindow(consoleHwnd, consoleRect.left, consoleRect.top, width, height, true);
        }
    }
}


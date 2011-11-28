module util.util;

import core.time;

import std.algorithm;
import std.conv;
import std.exception;
import std.stdio;
import std.range;
import std.string;
import std.traits;

public import std.datetime;

//TODO: Got order-dependant bugs here. If doing pos, stolen, worldparts, then we get bugs and bugs. sadface.
//import world.sector;
//import world.block;
import stolen.all;

version (Posix) {
    import core.sys.posix.stdlib: posix_memalign;
    import std.c.stdlib;
}

void msg(string file=__FILE__, int line=__LINE__, T...)(T t) {
    writeln(file, "(", line, "): ", t);
}

long utime() {
    return TickDuration.currSystemTick().usecs;
}

alias vector2d!(int)  vec2i;
alias vector2d!(float)  vec2f;
alias vector2d!(double)  vec2d;

alias vector3d!(int)  vec3i;
alias vector3d!(float)  vec3f;
alias vector3d!(double) vec3d;

alias aabbox3d!double aabbd;

vector3d!(A) convert(A,B)(const vector3d!(B) wap){
    return vector3d!A(to!A(wap.X), to!A(wap.Y), to!A(wap.Z));
}
vector2d!(A) convert(A,B)(const vector2d!(B) wap){
    return vector2d!A(to!A(wap.X), to!A(wap.Y));
}

vec3i getTilePos(T)(vector3d!T v){
    return vec3i(
        to!int(floor(v.X)),
        to!int(floor(v.Y)),
        to!int(floor(v.Z))
    );
}

//TODO: Replace this shit with stuff from std.bitmanip.
void setFlag(A,B)(ref A flags, B flag, bool value) {
    if (value) {
        flags |= flag;
    } else {
        flags &= ~flag;
    }
}

void BREAKPOINT(uint doBreak=1) {
    if(doBreak) {
        asm { int 3; }
    }
}
alias BREAKPOINT BREAK_IF;



unittest {
    SYSTEM_INFO si;
    GetSystemInfo(&si);
    assert(si.dwPageSize == 4096);
}

T[6] neighbors(T)(T t) {
    T[6] ret;
    ret[] = t;
    ret[0].value += vec3i(0,0,1);
    ret[1].value -= vec3i(0,0,1);
    ret[2].value += vec3i(0,1,0);
    ret[3].value -= vec3i(0,1,0);
    ret[4].value += vec3i(1,0,0);
    ret[5].value -= vec3i(1,0,0);
    return ret;
}


enum Direction{ //DERP DERP POLLUTING STUFF YEAH!
    eastCount=0,
    westCount=1,
    northCount=2,
    southCount=3,
    upCount=4,
    downCount=5,
    allCount=6,

    north = 1<<northCount,
    south = 1<<southCount,
    west  = 1<<westCount,
    east  = 1<<eastCount,
    up    = 1<<upCount,
    down  = 1<<downCount,

    all   = north | up | west | down | south | east,
}


void setThreadName(string threadName) {
    version(Windows){
        //
        // Usage: SetThreadName (-1, "MainThread");
        //
        //#include <windows.h>
        uint MS_VC_EXCEPTION=0x406D1388;

        struct THREADNAME_INFO{
            align(8):
           uint dwType; // Must be 0x1000.
           char* szName; // Pointer to name (in user addr space).
           uint dwThreadID; // Thread ID (-1=caller thread).
           uint dwFlags; // Reserved for future use, must be zero.
        };

        //const char* name = toStringz(threadName);
        char* name = cast(char*)(threadName ~ "\0").ptr;

        THREADNAME_INFO info;
        info.dwType = 0x1000;
        info.szName = to!(char*)(name);
        info.dwThreadID = GetCurrentThreadId();
        info.dwFlags = 0;

        uint* ptr = cast(uint*)&info;

        try//__try
        {
            RaiseException( MS_VC_EXCEPTION, 0u, info.sizeof/ptr.sizeof, ptr );
        }
        catch(Throwable o) //__except(EXCEPTION_EXECUTE_HANDLER)
        {
            msg("asdasdasd");
        }
    }
}

version(Windows){
    /*import win32.windows : GlobalAlloc, GlobalLock, GlobalUnlock, GMEM_MOVEABLE,
        OpenClipboard, EmptyClipboard, SetClipboardData, CF_TEXT, CloseClipboard, GetClipboardData;
    */
    import win32.windows;

    void setCopyString(string str) {
        auto strZ = str.toStringz();
        DWORD len = str.length+1;
        HANDLE hMem =  GlobalAlloc(GMEM_MOVEABLE, len);
        memcpy(GlobalLock(hMem), strZ, len);
        GlobalUnlock(hMem);
        OpenClipboard(null);
        EmptyClipboard();
        SetClipboardData(CF_TEXT, hMem);
        CloseClipboard();    
    }

    bool getCopyString(ref string output) {
        const(char*) clip;
        if (OpenClipboard(null)) {
            HANDLE hData = GetClipboardData( CF_TEXT );
            char * buffer = cast(char*)GlobalLock( hData );
            output = to!string(buffer);
            GlobalUnlock( hData );
            CloseClipboard();
            return true;
        }
        return false;
    }

}

unittest{
    setCopyString("dix\n");
    string s;
    assert(getCopyString(s), "Could not get string from clipboard");
    assert(s == "dix\n", "Didn't get correct string from clipboard");
}

CommonType!(T)[T.length] makeStackArray(T...)(T ts) {
    typeof(return) ret;
    foreach (i, t; ts) {
        ret[i] = t;
    }
    return ret;
}

Type clamp(Type)(Type val, Type min, Type max)
in{
    assert(min <= max, "Min must be less than or equal to max!");
}
body {
    if(val < min) {
        val = min;
    }
    if(val > max) {
        val = max;
    }
    return val;
}

module cgy.util.util;

import core.thread;
import core.time;

import std.algorithm;
import std.conv;
import std.exception;
import std.stdio;
import std.range;
import std.string;
import std.traits;
import std.typecons;
import std.typetuple;

//import derelict.sdl2.sdl;

import cgy.math.math : fastFloor;

//public import std.datetime;

//TODO: Got order-dependant bugs here. If doing pos, stolen, worldparts, then we get bugs and bugs. sadface.
//import worldstate.sector;
//import worldstate.block;
//import cgy.stolen.all;

//public import cgy.math.vector;

version (Posix) {
    import core.sys.posix.stdlib: posix_memalign;
    import std.c.stdlib;
}

version(Windows) {
    import cgy.windows;
}

ptrdiff_t workerID = -1; // thread local, set by scheduler

__gshared int g_gameTick;

void msg(string file=__FILE__, int line=__LINE__, T...)(T t) {
    writeln(g_gameTick % 100, ":", workerID, ": ", 
            file, "(", line, "): ", t);
}

long utime() {
    return TickDuration.currSystemTick().usecs;
}

long mstime() {
    return TickDuration.currSystemTick().msecs;
}


Thread spawnThread(T)(T func) {
    auto thread = new Thread(func);
    thread.start();
    return thread;
}

void setFlag(A,B)(ref A flags, B flag, bool value) {
    if (value) {
        flags |= flag;
    } else {
        flags &= ~flag;
    }
}

unittest {
    import windows;
    SYSTEM_INFO si;
    GetSystemInfo(&si);
    assert(si.dwPageSize == 4096);
}

void colorize(int num, int count, ref ubyte r, ref ubyte g, ref ubyte b) {
    immutable v = 2^^24;

    double ratio = (cast(double)num) / (count);
    int c = v - (cast(int)(cast(double)v * ratio));
    char* ptr = cast(char*)&c;
    r = ptr[0];
    g = ptr[1];
    b = ptr[2];
}

// Makes a tuple of tuples.
// First item in tuple will be a tuple, n long
// Second item in tuple will be a tuple, 2 long, same layout as first. I think?
template tuples(int n, Rest...) {
    static assert (Rest.length % n == 0);
    static if (Rest.length == 0) {
        alias TypeTuple!() tuples;
    } else {
        alias TypeTuple!(
                         tuple(Rest[0 .. n]),
                         tuples!(n, Rest[n .. $])) tuples;
    }
}

T[4] neighbors2D(T)(T t) {
    alias T V;
    T[4] ret;
    ret[] = t;
    ret[0] += V(0,1);
    ret[1] -= V(0,1);
    ret[2] += V(1,0);
    ret[3] -= V(1,0);
    return ret;
}

T[8] neighbors2D_8(T)(T t) {
    alias T V;
    T[8] ret;
    ret[] = t;
    ret[0] += V( 0, 1);
    ret[1] += V( 1, 1);
    ret[2] += V(-1, 1);
    ret[3] += V( 1, 0);
    ret[4] += V(-1, 0);
    ret[5] += V( 0,-1);
    ret[6] += V( 1,-1);
    ret[7] += V(-1,-1);
    return ret;
}


T[6] neighbors(T)(T t) {
    alias typeof(T.value) V;

    T[6] ret;
    ret[] = t;
    ret[0].value += V(0,0,1);
    ret[1].value -= V(0,0,1);
    ret[2].value += V(0,1,0);
    ret[3].value -= V(0,1,0);
    ret[4].value += V(1,0,0);
    ret[5].value -= V(1,0,0);
    return ret;
}


enum Direction{ //DERP DERP POLLUTING STUFF YEAH! // <--wat
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


version(Windows) {
    void RestartCoolGameYo() {
		//Find out how to start us
		//Do it
		//Crash
		ExitProcess(0);
    }
}

version(Windows){
    /*import win32.windows : GlobalAlloc, GlobalLock, GlobalUnlock, GMEM_MOVEABLE,
        OpenClipboard, EmptyClipboard, SetClipboardData, CF_TEXT, CloseClipboard, GetClipboardData;
    */

    void setCopyString(string str) {
        auto strZ = str.toStringz();
        DWORD len = cast(DWORD)str.length+1;
        HANDLE hMem =  GlobalAlloc(GMEM_MOVEABLE, len);
        core.stdc.string.memcpy(GlobalLock(hMem), strZ, len);
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
    /*setCopyString("dix\n");
    string s;
    assert(getCopyString(s), "Could not get string from clipboard");
    assert(s == "dix\n", "Didn't get correct string from clipboard");*/
}

version(Windows) {
    double getDoubleClickTime() {
        return GetDoubleClickTime() / 1_000.0;
    }
}

enum NDBAnswer {
    Ok,
    Retry_Cancel,
    Yes_No,
    Yes_No_Abort
}

version(Windows) {
    //ret: 1 is affermative, 2 is negative, 3 is HERPDERPBACON?
    int NativeDialogBox(string msg, string title, NDBAnswer a) {
        if(a == NDBAnswer.Retry_Cancel) {
            auto b = MessageBoxA(null, msg.toStringz, title.toStringz, cast(uint)MB_RETRYCANCEL);
            if(b == IDCANCEL) return 2;
            if(b == IDRETRY) return 1;
            enforce(0, "Derp? NOOOO! " ~ to!string(b));
        } else if(a == NDBAnswer.Ok) {
            auto b = MessageBoxA(null, msg.toStringz, title.toStringz, cast(uint)MB_OK);
        } else if(a == NDBAnswer.Yes_No) {
            auto b = MessageBoxA(null, msg.toStringz, title.toStringz, cast(uint)MB_YESNO);
            if(b == IDYES) return 1;
            if(b == IDNO) return 2;
            enforce(0, "Derp? NOOOO! " ~ to!string(b));
        } else {
            enforce(0, "NDB-choice not implemented:" ~ to!string(a));
        }
        return 0;
    }
}


CommonType!(T)[T.length] makeStackArray(T...)(T ts) {
    typeof(return) ret;
    foreach (i, t; ts) {
        ret[i] = t;
    }
    return ret;
}

void lazyInit(T, Us...)(ref T t, Us us) {
    if (t is null) {
        t = new T(us);
    }
}

void convertArray(string Op = "=", To, From)(To[] to, From[] from) {
    static if( is(To : From) && is(From : To) && To.sizeof == From.sizeof) {
        mixin("to[] " ~ Op ~ " from[];");
    } else static if( __traits(compiles, to[0].x)) {
        foreach(idx, ref val ; to) {
            mixin("val " ~ Op ~" from[idx].convert!(typeof(to[0].x));");
        }
    }else {
        foreach(idx, ref val ; to) {
            mixin("val " ~ Op ~" cast(To)from[idx];");
        }
    }
}

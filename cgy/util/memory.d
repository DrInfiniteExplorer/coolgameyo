

module util.memory;

import std.conv : to;
import std.exception;
import std.string;
import std.traits : arity, isArray, isDynamicArray, isAssociativeArray, isPointer, isSomeFunction, isCallable;

import windows;

import util.util : BREAK_IF;
import util.traits : RealMembers;

version(Windows){
    //    import std.c.windows.windows;
    //    import win32.windows : SYSTEM_INFO, GetSystemInfo, RaiseException; //Not available in std.c.windows.windows
}



void[] allocateBlob(size_t count, size_t blobSize) {
    version (Windows) {
        auto ret = VirtualAlloc(null, blobSize * count, MEM_COMMIT, PAGE_READWRITE);
        auto tmp = enforce(ret[0 .. blobSize*count], "memory allocation fail :-)");
        return tmp;
    } else version (Posix) {
        void* ret;
        auto result = posix_memalign(&ret, blobSize, blobSize * size);
        enforce (result == 0, "memory allocation fail :-)");
        return ret[0 .. blobSize * size];
    } else {
        static assert (0, "version?");
    }
}

void freeBlob(void* blob) {
    version (Windows) {
        VirtualFree(blob, 0, MEM_RELEASE);
    } else version (Posix) {
        free(blob);
    } else {
        static assert (0);
    }
}

struct ScopeMemory(T) {
    T* ptr;
    uint totalSize;
    this(uint size, uint count = 1) {
        ptr = cast(T*)allocateBlob(count, size);
        totalSize = size * count;
    }
    ~this() {
        freeBlob(ptr);
    }
    T[] opSlice() {
        return ptr[0 .. totalSize];
    }
    ref T opIndex(size_t index) {
        assert (index < totalSize);
        return ptr[index];
    }


}

version(Windows){
    //    import std.c.windows.windows;
    //    import win32.windows : SYSTEM_INFO, GetSystemInfo, RaiseException; //Not available in std.c.windows.windows

}

alias typeof(GetProcessMemoryInfo)* GetProcessMemoryInfoPtr;

extern(Windows) BOOL initGPMI(HANDLE h, PPROCESS_MEMORY_COUNTERS p, DWORD d) {
    HANDLE hh = LoadLibraryA("kernel32.dll");
    getProcessMemoryInfo = cast(typeof(getProcessMemoryInfo))GetProcAddress(hh, "GetProcessMemoryInfo");
    if(getProcessMemoryInfo is null) {
        hh = LoadLibraryA("psapi.dll");
        getProcessMemoryInfo = cast(typeof(getProcessMemoryInfo))GetProcAddress(hh, "GetProcessMemoryInfo");
        BREAK_IF(getProcessMemoryInfo is null);
    }
    return getProcessMemoryInfo(h,p,d);
}

__gshared GetProcessMemoryInfoPtr getProcessMemoryInfo = &initGPMI;

// Returns number of kilobytes of memory used.
ulong getMemoryUsage() {
    PROCESS_MEMORY_COUNTERS pmc;
    auto res = getProcessMemoryInfo(GetCurrentProcess(), &pmc, pmc.sizeof);
    BREAK_IF(!res);
    enforce(res, "Error calling GetProcessMemoryInfo");
    return pmc.WorkingSetSize/1024;
}

ulong getMemoryPageFaults() {
    PROCESS_MEMORY_COUNTERS data;
    enforce(getProcessMemoryInfo(GetCurrentProcess(), &data, data.sizeof), "Error calling GetProcessMemoryInfo");
    return data.PageFaultCount;
}

string MemDiff(string label, string varname = "memDiffStart")(){
    immutable diffName = varname ~ "Diff";
    return "auto " ~ varname ~ " = getMemoryUsage(); scope(exit) { auto "~diffName~"= getMemoryUsage() - "~varname~"; if("~diffName~") msg(\""~label~": \", "~diffName~");}";
}


ulong getCpuTimeMs() {
    import windows : FILETIME, GetProcessTimes, GetCurrentProcess;
    FILETIME creation, exit;
    FILETIME kernel;
    FILETIME user;
    GetProcessTimes(GetCurrentProcess(), &creation, &exit, &kernel, &user);

    ulong ulKernel = *cast(ulong*)&kernel;
    ulong ulUser = *cast(ulong*)&user;

    ulong total = ulKernel + ulUser;

    //filetime == X * 100ns = X * 0.1us
    return total / 10_000; // Should be ms?
}


struct BinaryWriter {
    alias void delegate(ubyte[]) WriterType;
    WriterType writer;

    void write(T)(T t) {
        static if(isArray!T) {
            ubyte[] array = cast(ubyte[])t;
            static if(isDynamicArray!T) {
                write(t.length.to!int);
            }
            writer(array);
        } else static if(isAssociativeArray!T) {
            write(t.length.to!int);
            foreach(key, value ; t) {
                write(key);
                write(value);
            }
        } else static if(isPointer!T) {
            static assert(0, "Cant write pointer types! Need some sort of.. magic.. conversion!");
        } else static if(isSomeFunction!T) {
            static assert(0, "Cant write function types! Need some sort of.. magic.. conversion!");
        } else static if( is(T == struct)) {
            foreach(member ; RealMembers!T) {
                write(mixin("t." ~ member));
            }
        } else {
            ubyte[] array = cast(ubyte[]) (&t)[0..1];
            writer(array);
        }
    }
}

struct BinaryMemoryReader {

    this(ubyte[] buff) {
        buffer = buff;
        reader = BinaryReader(&this.read);
    }
    ubyte[] buffer;
    BinaryReader reader;

    void read(ubyte[] dst) {
        dst[] = buffer[0 .. dst.length];
        buffer = buffer[dst.length .. $];
    }
}

struct BinaryReader {
    alias void delegate(ubyte[]) ReaderType;
    ReaderType reader;

    T read(T)() {
        T t;
        read!T(t);
        return t;
    }

    void read(T)(ref T t) {
        static if(isArray!T) {
            static if(isDynamicArray!T) {
                auto size = read!int;
                t.length = size;
            }
            ubyte[] array = cast(ubyte[])t;
            reader(array);
        } else static if(isAssociativeArray!T) {
            alias KeyType!T KeyType;
            alias ValueType!T ValueType;
            auto length = read!int;
            foreach(idx ; 0 .. length) {
                auto key = read!KeyType;
                auto value = read!ValueType;
                t[key] = value;
            }
        } else static if(isPointer!T) {
            static assert(0, "Cant read pointer types! Need some sort of.. magic.. conversion!");
        } else static if(isSomeFunction!T) {
            static assert(0, "Cant read function types! Need some sort of.. magic.. conversion!");
        } else static if( is(T == struct)) {
            foreach(member ; RealMembers!T) {
                alias typeof(__traits(getMember, t, member)) type;
                //pragma(msg, type.stringof ~ " " ~ T.stringof ~ "." ~ member);
                //pragma(msg, typeof(mixin("t." ~ member)).sizeof);
                //pragma(msg, typeof(__traits(getMember, t, member)).sizeof);
                //read!type(__traits(getMember, t, member));
                read(mixin("t." ~ member));
            }
        } else {
            ubyte[] array = cast(ubyte[]) (&t)[0..1];
            reader(array);
        }

    }
}


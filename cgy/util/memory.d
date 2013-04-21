

module util.memory;

import std.exception;
import std.string;

import windows;


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
    }
    return getProcessMemoryInfo(h,p,d);
}

__gshared GetProcessMemoryInfoPtr getProcessMemoryInfo = &initGPMI;

// Returns number of kilobytes of memory used.
ulong getMemoryUsage() {
    PROCESS_MEMORY_COUNTERS pmc;
    enforce(getProcessMemoryInfo(GetCurrentProcess(), &pmc, pmc.sizeof), "Error calling GetProcessMemoryInfo");
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





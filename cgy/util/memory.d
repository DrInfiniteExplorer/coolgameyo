

module util.memory;

import std.exception;
import std.string;

version(Windows){
    //    import std.c.windows.windows;
    //    import win32.windows : SYSTEM_INFO, GetSystemInfo, RaiseException; //Not available in std.c.windows.windows
    import win32.windows;
}

void[] allocateBlob(size_t size, size_t blobSize) {
    version (Windows) {
        auto ret = VirtualAlloc(null, blobSize * size, MEM_COMMIT, PAGE_READWRITE);
        auto tmp = enforce(ret[0 .. blobSize*size], "memory allocation fail :-)");
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

version(Windows){
    //    import std.c.windows.windows;
    //    import win32.windows : SYSTEM_INFO, GetSystemInfo, RaiseException; //Not available in std.c.windows.windows
    import win32.psapi;
}

alias typeof(GetProcessMemoryInfo)* GetProcessMemoryInfoPtr;

extern(Windows) BOOL initGPMI(HANDLE h, PPROCESS_MEMORY_COUNTERS p, DWORD d) {
    HANDLE hh = LoadLibrary("kernel32.dll");
    getProcessMemoryInfo = cast(typeof(getProcessMemoryInfo))GetProcAddress(hh, "GetProcessMemoryInfo");
    if(getProcessMemoryInfo is null) {
        hh = LoadLibrary("psapi.dll");
        getProcessMemoryInfo = cast(typeof(getProcessMemoryInfo))GetProcAddress(hh, "GetProcessMemoryInfo");
    }
    return getProcessMemoryInfo(h,p,d);
}

__gshared GetProcessMemoryInfoPtr getProcessMemoryInfo = &initGPMI;

string getMemoryUsage() { //Returns a string of memory info, ripe for display!
    PROCESS_MEMORY_COUNTERS pmc;
    enforce(getProcessMemoryInfo(GetCurrentProcess(), &pmc, pmc.sizeof), "Error calling GetProcessMemoryInfo");
    return format("%d", pmc.WorkingSetSize/1024);
}




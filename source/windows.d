module windows;

public import core.sys.windows.windows;

struct PROCESS_MEMORY_COUNTERS {
    DWORD cb;
    DWORD PageFaultCount;
    SIZE_T PeakWorkingSetSize;
    SIZE_T WorkingSetSize;
    SIZE_T QuotaPeakPagedPoolUsage;
    SIZE_T QuotaPagedPoolUsage;
    SIZE_T QuotaPeakNonPagedPoolUsage;
    SIZE_T QuotaNonPagedPoolUsage;
    SIZE_T PagefileUsage;
    SIZE_T PeakPagefileUsage;
}
alias PROCESS_MEMORY_COUNTERS* PPROCESS_MEMORY_COUNTERS;

// Flags for GlobalAlloc
const UINT
    GMEM_FIXED       = 0,
	GMEM_MOVEABLE    = 0x0002,
	GMEM_ZEROINIT    = 0x0040,
	GPTR             = 0x0040,
	GHND             = 0x0042,
	GMEM_MODIFY      = 0x0080,  // used only for GlobalRealloc
	GMEM_VALID_FLAGS = 0x7F72;

// Flags for clipboard
enum {
	CF_TEXT = 1,
	CF_BITMAP,
	CF_METAFILEPICT,
	CF_SYLK,
	CF_DIF,
	CF_TIFF,
	CF_OEMTEXT,
	CF_DIB,
	CF_PALETTE,
	CF_PENDATA,
	CF_RIFF,
	CF_WAVE,
	CF_UNICODETEXT,
	CF_ENHMETAFILE,
	CF_HDROP,
	CF_LOCALE,
	CF_MAX, // = 17
	CF_OWNERDISPLAY   = 128,
	CF_DSPTEXT,
	CF_DSPBITMAP,
	CF_DSPMETAFILEPICT, // = 131
	CF_DSPENHMETAFILE = 142,
	CF_PRIVATEFIRST   = 512,
	CF_PRIVATELAST    = 767,
	CF_GDIOBJFIRST    = 768,
	CF_GDIOBJLAST     = 1023
}

alias extern(Windows) UINT function (HWND, UINT, WPARAM, LPARAM) LPCCHOOKPROC;

struct CHOOSECOLORA {
	DWORD        lStructSize = CHOOSECOLORA.sizeof;
	HWND         hwndOwner;
	HWND         hInstance;
	COLORREF     rgbResult;
	COLORREF*    lpCustColors;
	DWORD        Flags;
	LPARAM       lCustData;
	LPCCHOOKPROC lpfnHook;
	LPCSTR       lpTemplateName;
}
alias CHOOSECOLORA* LPCHOOSECOLORA;
// flags for ChooseColor
enum : DWORD {
	CC_RGBINIT              = 0x0001,
	CC_FULLOPEN             = 0x0002,
	CC_PREVENTFULLOPEN      = 0x0004,
	CC_SHOWHELP             = 0x0008,
	CC_ENABLEHOOK           = 0x0010,
	CC_ENABLETEMPLATE       = 0x0020,
	CC_ENABLETEMPLATEHANDLE = 0x0040,
	CC_SOLIDCOLOR           = 0x0080,
	CC_ANYCOLOR             = 0x0100
}



extern(Windows) {
    BOOL GetProcessMemoryInfo(HANDLE, PPROCESS_MEMORY_COUNTERS, DWORD);
    DWORD GetCurrentThreadId();
    void RaiseException(DWORD, DWORD, DWORD, DWORD_PTR);
    void ExitProcess(UINT);

    HGLOBAL GlobalAlloc(UINT, DWORD);
    LPVOID GlobalLock(HGLOBAL);

    BOOL OpenClipboard(HWND);
    BOOL EmptyClipboard();
    HANDLE SetClipboardData(UINT, HANDLE);
    HANDLE GetClipboardData(UINT);
    BOOL CloseClipboard();

    UINT GetDoubleClickTime();

    HWND FindWindowA(LPCSTR, LPCSTR);
    HWND GetConsoleWindow();
    BOOL MoveWindow(HWND, int, int, int, int, BOOL);

    BOOL ChooseColorA(LPCHOOSECOLORA);


    BOOL IsDebuggerPresent();

}
//*
extern(Windows) BOOL SetDllDirectoryA(LPCSTR lpPathName);
/*/
template LoadWrapper(string Func, string dll, string funcName) {
    import std.traits;
    import util.util;
    mixin("alias ParameterTypeTuple!" ~ Func ~ "  Params;");
    mixin("alias ReturnType!" ~ Func ~ "  Return;");
    // Falls on unautomatic detection of extern(Windows) atm.
    Return LoadWrapper(Params params) {
        HANDLE hh = LoadLibraryA(dll);
        mixin(Func) = cast(typeof(mixin(Func)))GetProcAddress(hh, funcName);
        if(mixin(Func) is null) {
            msg("Could not load ", funcName, " from ", dll, " to ", Func);
            BREAKPOINT;
        }
        msg("asd",params[0],"asd");
        return mixin(Func)(params);
        pragma(msg, typeof(return));
        pragma(msg, Params);
    }
}

alias extern(Windows) BOOL function(LPCTSTR lpPathName) SetDllDirectoryFunc;
__gshared SetDllDirectoryFunc SetDllDirectoryA = &LoadWrapper!("SetDllDirectoryA", "kernel32.dll", "SetDllDirectoryA");
//*/


shared static this() {
	import std.string : toStringz;
	import std.path : dirName;

    version(Win32) {
        SetDllDirectoryA("bin\\x86\\");
    }
    version(Win64) {
		char[512] exePath;
		auto len = GetModuleFileNameA(null, exePath.ptr, exePath.sizeof);
		exePath[len] = 0;
		auto binPath = exePath.dirName ~ r"\bin\x64\";
        SetDllDirectoryA(binPath.toStringz());
		//SetDllDirectoryA(r"e:\D\coolgameyo\gameroot\bin\x64");
	
    }
}

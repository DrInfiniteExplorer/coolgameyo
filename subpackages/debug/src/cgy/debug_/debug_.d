module cgy.debug_.debug_;

void BREAK_IF(uint doBreak) {
    if(doBreak) {
        asm { int 3; }
    }
}
void BREAKPOINT() {
    asm { int 3; }
}

version(Windows){
    import core.sys.windows.windows : DWORD, DWORD_PTR, BOOL;
    extern(Windows) DWORD GetCurrentThreadId();
    extern(Windows) BOOL IsDebuggerPresent();
    extern(Windows) void RaiseException(DWORD, DWORD, DWORD, DWORD_PTR);
}
void setThreadName(string threadName) {
    version(Windows){


        import std.conv : to;
        import std.string : toStringz;
        //
        // Usage: SetThreadName (-1, "MainThread");
        //
        //#include <windows.h>
        uint MS_VC_EXCEPTION=0x406D1388;

        struct THREADNAME_INFO{
            align(8):
            uint dwType; // Must be 0x1000.
            immutable(char)* szName; // Pointer to name (in user addr space).
            uint dwThreadID; // Thread ID (-1=caller thread).
            uint dwFlags; // Reserved for future use, must be zero.
        }

        //const char* name = toStringz(threadName);
        immutable char* name = threadName.toStringz;

        THREADNAME_INFO info;
        info.dwType = 0x1000;
        info.szName = name;
        info.dwThreadID = GetCurrentThreadId();
        info.dwFlags = 0;

        uint* ptr = cast(uint*)&info;
        DWORD_PTR ptrAsDWORD = cast(DWORD_PTR)ptr;

        try//__try
        {
            version(LDC) {
                pragma(msg, "LDC compiled programs crashes with this");
            }
            else{
                version(Win64){
                    if(IsDebuggerPresent()) {
                        //RaiseException( MS_VC_EXCEPTION, 0u, info.sizeof/ptr.sizeof, ptrAsDWORD );
                    }
                } else {
                    RaiseException( MS_VC_EXCEPTION, 0u, info.sizeof/ptr.sizeof, ptrAsDWORD );
                }
            }
        }
        catch(Throwable o) //__except(EXCEPTION_EXECUTE_HANDLER)
        {
            // wtf is this shit
            //msg("asdasdasd");
        }
    }
}
#pragma once

#ifdef WIN32
#include <Windows.h>
#endif

#ifdef WIN32
#include <irrlicht.h>
#else
#include <irrlicht/irrlicht.h>
#endif

#ifdef BREAKPOINT
    static_assert(0, "ERROR BREAKPOINT ALREADY DEFINED");    
#endif 
#ifdef ASSERT
    static_assert(0, "ERROR_ASSERT_ALREADY_DEFINED");
#endif

#ifdef WIN32
#define BREAKPOINT __asm int 3;
inline void ASSERT(int x)
{
    if (!x) {
        BREAKPOINT;
    }
}
#else
/* Might want to make this something awesome or somesuch */
#define BREAKPOINT assert (0);
#endif

#ifdef WIN32
#define TLS __declspec(thread)
inline void* AllocateBlob(size_t size) {
    return VirtualAlloc(NULL, 4096 * size, MEM_COMMIT, PAGE_READWRITE);
}
inline void FreeBlob(void* page) {
    VirtualFree(page, 0, MEM_RELEASE);
}
#else
#define TLS __thread
inline void* AllocatePage() {
    return valloc(4096);
}
inline void FreePage(void* page) {
    vfree(page);
}
#endif


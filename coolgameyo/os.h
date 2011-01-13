#pragma once

#ifdef WIN32
#include <Windows.h>
#endif

#ifdef WIN32
#include <irrlicht.h>
#else
#include <irrlicht/irrlicht.h>
#endif

#ifdef WIN32
#define BREAKPOINT __asm int 3;
#else
/* Might want to make this something awesome or somesuch */
#define BREAKPOINT assert (0);
#endif

#ifdef WIN32
#define TLS __declspec(thread)
inline void* AllocatePage() {
    return VirtualAlloc(NULL, 4096, MEM_COMMIT, PAGE_READWRITE);
}
inline void FreePage(void* page) {
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


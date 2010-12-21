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


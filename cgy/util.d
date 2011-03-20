import engine.irrlicht;
import core.stdc.stdio;

alias int s32;
alias uint u32;
alias float f32;
alias double f64;

alias vector3d!(int) vec3i;


#pragma once

#include <map>
#include <set>
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <utility>

//#include <thread>

#include "os.h"

#define assert(X) do { if (!(X)) BREAKPOINT; } while (0)

using namespace irr;
using namespace irr::core;
using namespace irr::scene;
using namespace irr::video;

template <typename A, typename B>
inline vector3d<A> convert(const vector3d<B> in){
    return vector3d<A>(
        (A)in.X,
        (A)in.Y,
        (A)in.Z);
}

typedef vector3d<f64> vec3d;
typedef vector3df vec3f;
typedef vector3di vec3i;
typedef vector2di vec2i;

/*

Porta? Behålla alls? Hur göra templatefunc utan klass?

template <typename A, typename B>
inline void SetFlag(A &val, B flag) {
    val |= flag;
}

template <typename A, typename B>
inline void ClearFlag(A &val, B flag) {
    val &= ~flag;
}

template <typename A, typename B>
inline A GetFlag(A val, B flag) {
    return val & flag;
}

template <typename A, typename B>
inline void SetFlag(A &val, B flag, bool Value) {
    if (Value) {
        SetFlag(val, flag);
    } else {
        ClearFlag(val, flag);
    }
}
*/

void BREAKPOINT(){
	asm{
		int 3;
	}
}

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

ASDASDASDASDAsd




struct Neighbors
{
    vec3i pos;
    vec3i lol[6];
    size_t i;
	
    this(vec3i me)
    {
		pos = me;
        lol[0] = me + vec3i(0,0,1);
        lol[1] = me - vec3i(0,0,1);
        lol[2] = me + vec3i(0,1,0);
        lol[3] = me - vec3i(0,1,0);
        lol[4] = me + vec3i(1,0,0);
        lol[5] = me - vec3i(1,0,0);
    }
    this(vec3i __pos, vec3i* wap, size_t __i)
    {
		pos = __pos;
		i = __i;
        lol = *wap;
    }

	vec3i front() {
		return lol[i];
	}
	void popFront() {
		i += 1;
	}
	bool empty() {
		return i >= 6;
	}

};

struct RangeFromTo
{
    int bx,ex,by,ey,bz,ez;
    int x,y,z;
    this(int beginX, int endX,
        int beginY, int endY,
        int beginZ, int endZ)
    {
		x = bx = beginX;
		ex = endX;
		y = by = beginY;
		ey = endY;
		z = bz = beginZ;
		ez = endZ;
	}
    this(int beginX, int endX,
        int beginY, int endY,
        int beginZ, int endZ,
        int __x, int __y, int __z)
	{
		x = __x;
		bx = beginX;
		ex = endX;
		y = __y;
		by = beginY;
		ey = endY;
		z = __z;
		bz = beginZ;
		ez = endZ;
	}
	
	vec3i front() {
		return vec3i(x, y, z);
	}
	void popFront() {
        x += 1;
        if (x < ex) return; 
        x = bx;
        y += 1;
        if (y < ey) return;
        y = by;
        z += 1;
	}
	bool empty() {
		return x == ex && y == ey && z == ez;
	}
};
/* Returns a/b rounded towards -inf instead of rounded towards 0 */
s32 NegDiv(const s32 a, const s32 b)
in{
	assert(b >0);
}
body{
    static assert(15/8 == 1);
    static assert(8/8 == 1);

    static assert(7/8 == 0);
    static assert(0/8 == 0);

    static assert((-1-7)/8 == -1);
    static assert((-8-7)/8 == -1);

    static assert((-9-7)/8 == -2);

	if (a < 0) {
		return (a-b+1)/b;
	}
	return a/b;
}

/* Snaps to multiples of b. See enforceions. */
s32 Snap(const s32 a, const s32 b)
in{
	assert(b > 0);
}
body{
    static assert( (-16-7)-(-16-7)  % 8 ==  -16);
    static assert( (-9-7)-(-9-7)  % 8 ==  -16);

    static assert( (-8-7)-(-8-7)  % 8 ==  -8);
    static assert( (-1-7)-(-1-7)  % 8 ==  -8);

    static assert(  0- 0  % 8 ==  0);
    static assert(  7- 7  % 8 ==  0);

    static assert(  8- 8  % 8 ==  8);
    static assert( 15- 15 % 8 ==  8);

    if(a<0){
        auto x = a-b+1;
        return x - (x % b);
    }
    return a - a % b;
    //return NegDiv(a,b) * b;
}

s32 PosMod(const s32 a, const s32 b){
    static assert( ((15 % 8)+8)%8 == 7);
    static assert(  ((8 % 8)+8)%8 == 0);

    static assert( ((7 % 8)+8)%8  == 7);
    static assert( ((0 % 8)+8)%8  == 0);

    static assert( ((-1 % 8)+8)%8  == 7);
    static assert( ((-8 % 8)+8)%8  == 0);

    static assert( ((-9 % 8)+8)%8  == 7);
    static assert( ((-16% 8)+8)%8  == 0);

    return ((a % b) + b) % b;
}

/*  These functions are return a vector representing the  */
/*  index of the tile, relative to a <higher level> so that */
/*  the returned index can safely be used to find the <thing> */
/*  withing the <bigger thing>. Return values lie in the domain */
/*  [0, <bigger thing>_SIZE_?[  */
vec3i GetBlockRelativeTileIndex(const vec3i tilePosition){

    return vec3i(
        PosMod(tilePosition.X, BLOCK_SIZE_X),
        PosMod(tilePosition.Y, BLOCK_SIZE_Y),
        PosMod(tilePosition.Z, BLOCK_SIZE_Z)
        );
}
/*  See GetBlockRelativeTileIndex for description  */
vec3i GetSectorRelativeBlockIndex(const vec3i tilePosition){
    return vec3i(
        PosMod(NegDiv(tilePosition.X, TILES_PER_BLOCK_X), SECTOR_SIZE_X),
        PosMod(NegDiv(tilePosition.Y, TILES_PER_BLOCK_Y), SECTOR_SIZE_Y),
        PosMod(NegDiv(tilePosition.Z, TILES_PER_BLOCK_Z), SECTOR_SIZE_Z)
      );
}






/*  Returns the position of the first tile in this block as  */
/*  world tile coordinates. It is where the block starts.  */
vec3i GetBlockWorldPosition (const vec3i tilePosition){   
    return vec3i(
        Snap(tilePosition.X, TILES_PER_BLOCK_X),
        Snap(tilePosition.Y, TILES_PER_BLOCK_Y),
        Snap(tilePosition.Z, TILES_PER_BLOCK_Z)
        );
}

/*  Returns a vector which corresponds to the sector number in the  */
/*  world that the tile belongs to. Can be (0, 0, 0) or (1, 5, -7). */
/*  See Util::Test for usage and stuff  */
vec3i GetSectorNumber(const vec3i tilePosition){
    return vec3i(
        Snap(tilePosition.X, TILES_PER_SECTOR_X)/TILES_PER_SECTOR_X,
        Snap(tilePosition.Y, TILES_PER_SECTOR_Y)/TILES_PER_SECTOR_Y,
        Snap(tilePosition.Z, TILES_PER_SECTOR_Z)/TILES_PER_SECTOR_Z
        );
}



unittest {

    assert(NegDiv(15, 8) == 1);
    assert(NegDiv( 8, 8) == 1);
    assert(NegDiv( 7, 8) == 0);
    assert(NegDiv( 0, 8) == 0);
    assert(NegDiv(-1, 8) == -1);
    assert(NegDiv(-8, 8) == -1);
    assert(NegDiv(-9, 8) == -2);

    //printf("%d\n\n\n", Snap(-16,  8));
    assert(Snap(-16,  8) == -16);
    assert(Snap( -9,  8) == -16);
    assert(Snap( -8,  8) == -8);
    assert(Snap( -1,  8) == -8);
    assert(Snap(  0,  8) == 0);
    assert(Snap(  7,  8) == 0);
    assert(Snap(  8,  8) == 8);
    assert(Snap( 15,  8) == 8);

    assert(PosMod(-9, 8) == 7);
    assert(PosMod(-8, 8) == 0);
    assert(PosMod(-1, 8) == 7);
    assert(PosMod( 0, 8) == 0);
    assert(PosMod( 7, 8) == 7);
    assert(PosMod( 8, 8) == 0);

    /*  Sector number tests  */
    assert(GetSectorNumber(vec3i(-TILES_PER_SECTOR_X,   -TILES_PER_SECTOR_Y , -TILES_PER_SECTOR_Z ))    == vec3i(-1, -1, -1));
    assert(GetSectorNumber(vec3i(-1,                    -1,                 -1))                        == vec3i(-1, -1, -1));
    assert(GetSectorNumber(vec3i(0,                     0,                  0))                         == vec3i( 0,  0,  0));
    assert(GetSectorNumber(vec3i(TILES_PER_SECTOR_X-1,  TILES_PER_SECTOR_Y-1, TILES_PER_SECTOR_Z-1))    == vec3i( 0,  0,  0));
    assert(GetSectorNumber(vec3i(TILES_PER_SECTOR_X  ,  TILES_PER_SECTOR_Y  , TILES_PER_SECTOR_Z  ))    == vec3i( 1,  1,  1));

    /*  tile index tests  */
    assert(GetBlockRelativeTileIndex(vec3i(-1, -1, -1)) == vec3i(BLOCK_SIZE_X-1, BLOCK_SIZE_Y-1, BLOCK_SIZE_Z-1));
    assert(GetBlockRelativeTileIndex(vec3i(TILES_PER_BLOCK_X-1,  TILES_PER_BLOCK_Y-1,  TILES_PER_BLOCK_Z-1)) == vec3i(BLOCK_SIZE_X-1, BLOCK_SIZE_Y-1, BLOCK_SIZE_Z-1));
    assert(GetBlockRelativeTileIndex(vec3i( 0,  0,  0)) == vec3i(0, 0, 0));
    assert(GetBlockRelativeTileIndex(vec3i( TILES_PER_BLOCK_X  ,  TILES_PER_BLOCK_Y  ,  TILES_PER_BLOCK_Z  )) == vec3i(0, 0, 0));


    /*  Block world position, where block start in world, tile-counted  */
    assert(GetBlockWorldPosition(vec3i(-1, -1, -1)) == vec3i(-TILES_PER_BLOCK_X, -TILES_PER_BLOCK_Y, -TILES_PER_BLOCK_Z));
    assert(GetBlockWorldPosition(vec3i( 0,  0,  0)) == vec3i(0, 0, 0));
    assert(GetBlockWorldPosition(vec3i( TILES_PER_BLOCK_X,  TILES_PER_BLOCK_Y,  TILES_PER_BLOCK_Z)) == vec3i(TILES_PER_BLOCK_X, TILES_PER_BLOCK_Y, TILES_PER_BLOCK_Z));



    int[5][5][5] x;
	x[] = 0;
    auto range = RangeFromTo(0,5,0,5,0,5);
    foreach (p; range) {
        x[p.X][p.Y][p.Z] = 1;
    }
    auto xx = &x[0][0][0];
    for (int i = 0; i < (x.sizeof /x[0].sizeof ); i += 1) {
        if (xx[i] != 1) {
            printf("Something terrible! %d\n", xx[i]);
            BREAKPOINT;
        }
    }
}



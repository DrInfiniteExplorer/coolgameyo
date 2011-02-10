#pragma once

#include "Sector.h"

/* Returns a/b rounded towards -inf instead of rounded towards 0 */
s32 NegDiv(const s32 a, const s32 b);



/*  These functions are return a vector representing the  */
/*  index of the tile, relative to a <higher level> so that */
/*  the returned index can safely be used to find the <thing> */
/*  withing the <bigger thing>. Return values lie in the domain */
/*  [0, <bigger thing>_SIZE_?[  */
vec3i GetBlockRelativeTileIndex(const vec3i &tilePosition);
/*  See GetBlockRelativeTileIndex for description  */
vec3i GetChunkRelativeBlockIndex(const vec3i &tilePosition);
/*  See GetBlockRelativeTileIndex for description  */
vec3i GetSectorRelativeChunkIndex(const vec3i &tilePosition);


/*  Returns the position of the first tile in this block as  */
/*  world tile coordinates. It is where the block starts.  */
vec3i GetBlockWorldPosition (const vec3i &tilePosition);


/*  Returns a vector which corresponds to the sector number in the  */
/*  world that the tile belongs to. Can be (0, 0, 0) or (1, 5, -7). */
vec3i GetSectorNumber(const vec3i &tilePosition);


namespace Util {
    void Test();
}


struct RangeFromTo
{
    int bx,ex,by,ey,bz,ez;
    int x,y,z;
    RangeFromTo(int beginX, int endX,
        int beginY, int endY,
        int beginZ, int endZ)
        : bx(beginX), ex(endX), 
        by(beginY), ey(endY), 
        bz(beginZ), ez(endZ), 
        x(beginX), y(beginY), z(beginZ)
    { }
    RangeFromTo(int beginX, int endX,
        int beginY, int endY,
        int beginZ, int endZ,
        int x, int y, int z)
        : bx(beginX), ex(endX),
        by(beginY), ey(endY),
        bz(beginZ), ez(endZ),
        x(x), y(y), z(z)
    { }

    RangeFromTo begin() const { return RangeFromTo(bx,ex,by,ey,bz,ez,bx,by,bz); }
    RangeFromTo end()   const { return RangeFromTo(bx,ex,by,ey,bz,ez,bx,by,ez); }       
    vec3i operator * () const { return vec3i(x,y,z); }
    bool operator != (const RangeFromTo other) const
    {
        return x != other.x || y != other.y || z != other.z;
    }
    RangeFromTo& operator ++ ()
    {
        x += 1;
        if (x < ex) return *this; 
        x = bx;
        y += 1;
        if (y < ey) return *this;
        y = by;
        z += 1;
        return *this;
    }
};
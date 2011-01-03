#include "Util.h"



/* Returns a/b rounded towards -inf instead of rounded towards 0 */
s32 NegDiv(const s32 a, const s32 b){
    static_assert(15/8 == 1, "asd");
    static_assert(8/8 == 1, "asd");

    static_assert(7/8 == 0, "asd");
    static_assert(0/8 == 0, "asd");

    static_assert((-1-7)/8 == -1, "asd");
    static_assert((-8-7)/8 == -1, "asd");

    static_assert((-9-7)/8 == -2, "asd");

    assert (b > 0);

    if (a < 0) {
        return (a-b+1)/b;
    }
    return a/b;
}

/* Snaps to multiples of b. See assertions. */
s32 Snap(const s32 a, const s32 b){
    static_assert( (-16-7)-(-16-7)  % 8 ==  -16, "Blargh");
    static_assert( (-9-7)-(-9-7)  % 8 ==  -16, "Blargh");

    static_assert( (-8-7)-(-8-7)  % 8 ==  -8, "Blargh");
    static_assert( (-1-7)-(-1-7)  % 8 ==  -8, "Blargh");

    static_assert(  0- 0  % 8 ==  0, "Blargh");
    static_assert(  7- 7  % 8 ==  0, "Blargh");

    static_assert(  8- 8  % 8 ==  8, "Blargh");
    static_assert( 15- 15 % 8 ==  8, "Blargh");

    assert (b > 0);

    //return NegDiv(a,b) * b;

    if(a<0){
        auto x = a-b+1;
        return x - (x % b);
    }
    return a - a % b;
}



vec3i GetBlockRelativeTilePosition  (const vec3i &tilePosition){

    static_assert( 15 % 8 == 7, "asd");
    static_assert(  8 % 8 == 0, "asd");

    static_assert( 7 % 8  == 7, "asd");
    static_assert( 0 % 8  == 0, "asd");

    static_assert(7 +((1-1)%8) == 7, "DASD");
    static_assert(7 +((1-8)%8) == 0, "DASD");

    static_assert(7 +((1-9)%8) == 7, "DASD");
    static_assert(7 +((1-16)%8) == 0, "DASD");

    return vec3i(
        abs(tilePosition.X % BLOCK_SIZE_X),
        abs(tilePosition.Y % BLOCK_SIZE_Y),
        abs(tilePosition.Z % BLOCK_SIZE_Z)
    );
}

vec3i GetChunkRelativeBlockPosition (const vec3i &tilePosition){

    return vec3i(
          abs((tilePosition.X / TILES_PER_BLOCK_X) % CHUNK_SIZE_X),
          abs((tilePosition.Y / TILES_PER_BLOCK_Y) % CHUNK_SIZE_Y),
          abs((tilePosition.Z / TILES_PER_BLOCK_Z) % CHUNK_SIZE_Z)
      );
}

vec3i GetSectorRelativeChunkPosition(const vec3i &tilePosition){
    return vec3i(
          abs((tilePosition.X / TILES_PER_CHUNK_X) % SECTOR_SIZE_X),
          abs((tilePosition.Y / TILES_PER_CHUNK_Y) % SECTOR_SIZE_Y),
          abs((tilePosition.Z / TILES_PER_CHUNK_Z) % SECTOR_SIZE_Z)
      );
}


vec3i GetBlockWorldPosition (const vec3i &tilePosition){   
    return vec3i(
        tilePosition.X - tilePosition.X % TILES_PER_BLOCK_X,
        tilePosition.Y - tilePosition.Y % TILES_PER_BLOCK_Y,
        tilePosition.Z - tilePosition.Z % TILES_PER_BLOCK_Z
        );
}
vec3i GetChunkWorldPosition (const vec3i &tilePosition){
    return vec3i(
        tilePosition.X - tilePosition.X % TILES_PER_CHUNK_X,
        tilePosition.Y - tilePosition.Y % TILES_PER_CHUNK_Y,
        tilePosition.Z - tilePosition.Z % TILES_PER_CHUNK_Z
        );
}

vec3i GetSectorWorldPosition(const vec3i &tilePosition)
{
    return vec3i(
        tilePosition.X - tilePosition.X % TILES_PER_SECTOR_X,
        tilePosition.Y - tilePosition.Y % TILES_PER_SECTOR_Y,
        tilePosition.Z - tilePosition.Z % TILES_PER_SECTOR_Z
        );
}







vec3i GetBlockPosition (const vec3i &tilePosition){
    return vec3i(
        tilePosition.X / TILES_PER_BLOCK_X,
        tilePosition.Y / TILES_PER_BLOCK_Y,
        tilePosition.Z / TILES_PER_BLOCK_Z
        );
}

vec3i GetChunkPosition (const vec3i &tilePosition)
{
    return vec3i(
        tilePosition.X / TILES_PER_CHUNK_X,
        tilePosition.Y / TILES_PER_CHUNK_Y,
        tilePosition.Z / TILES_PER_CHUNK_Z
        );
}

vec3i GetSectorPosition(const vec3i &tilePosition)
{
    return vec3i(
        tilePosition.X / TILES_PER_SECTOR_X,
        tilePosition.Y / TILES_PER_SECTOR_Y,
        tilePosition.Z / TILES_PER_SECTOR_Z
        );
}



namespace Util {
    void Test() {

        assert(NegDiv(15, 8) == 1);
        assert(NegDiv( 8, 8) == 1);
        assert(NegDiv( 7, 8) == 0);
        assert(NegDiv( 0, 8) == 0);
        assert(NegDiv(-1, 8) == -1);
        assert(NegDiv(-8, 8) == -1);
        assert(NegDiv(-9, 8) == -2);

        printf("%d\n\n\n", Snap(-16,  8));
        assert(Snap(-16,  8) == -16);
        assert(Snap( -9,  8) == -16);
        assert(Snap( -8,  8) == -8);
        assert(Snap( -1,  8) == -8);
        assert(Snap(  0,  8) == 0);
        assert(Snap(  7,  8) == 0);
        assert(Snap(  8,  8) == 8);
        assert(Snap( 15,  8) == 8);
    }
}


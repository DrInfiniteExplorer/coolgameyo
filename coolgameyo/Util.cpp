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

    ASSERT(b >0);

    if (a < 0) {
        return (a-b+1)/b;
    }
    return a/b;
}

/* Snaps to multiples of b. See ASSERTions. */
s32 Snap(const s32 a, const s32 b){
    static_assert( (-16-7)-(-16-7)  % 8 ==  -16, "Blargh");
    static_assert( (-9-7)-(-9-7)  % 8 ==  -16, "Blargh");

    static_assert( (-8-7)-(-8-7)  % 8 ==  -8, "Blargh");
    static_assert( (-1-7)-(-1-7)  % 8 ==  -8, "Blargh");

    static_assert(  0- 0  % 8 ==  0, "Blargh");
    static_assert(  7- 7  % 8 ==  0, "Blargh");

    static_assert(  8- 8  % 8 ==  8, "Blargh");
    static_assert( 15- 15 % 8 ==  8, "Blargh");

    ASSERT (b > 0);

    //return NegDiv(a,b) * b;

    if(a<0){
        auto x = a-b+1;
        return x - (x % b);
    }
    return a - a % b;
}

s32 PosMod_IF(const s32 a, const s32 b){
    static_assert( 15 % 8 == 7, "asd");
    static_assert(  8 % 8 == 0, "asd");

    static_assert( 7 % 8  == 7, "asd");
    static_assert( 0 % 8  == 0, "asd");

    static_assert(7 +((1-1)%8) == 7, "DASD");
    static_assert(7 +((1-8)%8) == 0, "DASD");

    static_assert(7 +((1-9)%8) == 7, "DASD");
    static_assert(7 +((1-16)%8) == 0, "DASD");

    if (a<0) {
       return b-1  +(1+a)%b;
    }
    return a%b;
}

s32 PosMod(const s32 a, const s32 b){
    static_assert( ((15 % 8)+8)%8 == 7, "asd");
    static_assert(  ((8 % 8)+8)%8 == 0, "asd");

    static_assert( ((7 % 8)+8)%8  == 7, "asd");
    static_assert( ((0 % 8)+8)%8  == 0, "asd");

    static_assert( ((-1 % 8)+8)%8  == 7, "asd");
    static_assert( ((-8 % 8)+8)%8  == 0, "asd");

    static_assert( ((-9 % 8)+8)%8  == 7, "asd");
    static_assert( ((-16% 8)+8)%8  == 0, "asd");

    return ((a % b) + b) % b;
}

/*  These functions are return a vector representing the  */
/*  index of the tile, relative to a <higher level> so that */
/*  the returned index can safely be used to find the <thing> */
/*  withing the <bigger thing>. Return values lie in the domain */
/*  [0, <bigger thing>_SIZE_?[  */
vec3i GetBlockRelativeTileIndex(const vec3i &tilePosition){

    return vec3i(
        PosMod(tilePosition.X, BLOCK_SIZE_X),
        PosMod(tilePosition.Y, BLOCK_SIZE_Y),
        PosMod(tilePosition.Z, BLOCK_SIZE_Z)
        );
}
/*  See GetBlockRelativeTileIndex for description  */
vec3i GetChunkRelativeBlockIndex(const vec3i &tilePosition){
    return vec3i(
        PosMod(NegDiv(tilePosition.X, TILES_PER_BLOCK_X), CHUNK_SIZE_X),
        PosMod(NegDiv(tilePosition.Y, TILES_PER_BLOCK_Y), CHUNK_SIZE_Y),
        PosMod(NegDiv(tilePosition.Z, TILES_PER_BLOCK_Z), CHUNK_SIZE_Z)
      );
}
/*  See GetBlockRelativeTileIndex for description  */
vec3i GetSectorRelativeChunkIndex(const vec3i &tilePosition){
    return vec3i(
        PosMod(NegDiv(tilePosition.X, TILES_PER_CHUNK_X), SECTOR_SIZE_X),
        PosMod(NegDiv(tilePosition.Y, TILES_PER_CHUNK_Y), SECTOR_SIZE_Y),
        PosMod(NegDiv(tilePosition.Z, TILES_PER_CHUNK_Z), SECTOR_SIZE_Z)
      );
}






/*  Returns the position of the first tile in this block as  */
/*  world tile coordinates. It is where the block starts.  */
vec3i GetBlockWorldPosition (const vec3i &tilePosition){   
    return vec3i(
        Snap(tilePosition.X, TILES_PER_BLOCK_X),
        Snap(tilePosition.Y, TILES_PER_BLOCK_Y),
        Snap(tilePosition.Z, TILES_PER_BLOCK_Z)
        );
}
/*
Implement lite GetBlockWorldPosition

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
*/




/*
Implement as getSectorNum
vec3i GetBlockNumber (const vec3i &tilePosition){
    return vec3i(
        tilePosition.X / TILES_PER_BLOCK_X,
        tilePosition.Y / TILES_PER_BLOCK_Y,
        tilePosition.Z / TILES_PER_BLOCK_Z
        );
}

vec3i GetChunkNumber (const vec3i &tilePosition)
{
    return vec3i(
        tilePosition.X / TILES_PER_CHUNK_X,
        tilePosition.Y / TILES_PER_CHUNK_Y,
        tilePosition.Z / TILES_PER_CHUNK_Z
        );
}

/*

/*  Returns a vector which corresponds to the sector number in the  */
/*  world that the tile belongs to. Can be (0, 0, 0) or (1, 5, -7). */
/*  See Util::Test for usage and stuff  */
vec3i GetSectorNumber(const vec3i &tilePosition){
    return vec3i(
        Snap(tilePosition.X, TILES_PER_SECTOR_X)/TILES_PER_SECTOR_X,
        Snap(tilePosition.Y, TILES_PER_SECTOR_Y)/TILES_PER_SECTOR_Y,
        Snap(tilePosition.Z, TILES_PER_SECTOR_Z)/TILES_PER_SECTOR_Z
        );
}



namespace Util {
    void Test() {

        ASSERT(NegDiv(15, 8) == 1);
        ASSERT(NegDiv( 8, 8) == 1);
        ASSERT(NegDiv( 7, 8) == 0);
        ASSERT(NegDiv( 0, 8) == 0);
        ASSERT(NegDiv(-1, 8) == -1);
        ASSERT(NegDiv(-8, 8) == -1);
        ASSERT(NegDiv(-9, 8) == -2);

        //printf("%d\n\n\n", Snap(-16,  8));
        ASSERT(Snap(-16,  8) == -16);
        ASSERT(Snap( -9,  8) == -16);
        ASSERT(Snap( -8,  8) == -8);
        ASSERT(Snap( -1,  8) == -8);
        ASSERT(Snap(  0,  8) == 0);
        ASSERT(Snap(  7,  8) == 0);
        ASSERT(Snap(  8,  8) == 8);
        ASSERT(Snap( 15,  8) == 8);

        ASSERT(PosMod(-9, 8) == 7);
        ASSERT(PosMod(-8, 8) == 0);
        ASSERT(PosMod(-1, 8) == 7);
        ASSERT(PosMod( 0, 8) == 0);
        ASSERT(PosMod( 7, 8) == 7);
        ASSERT(PosMod( 8, 8) == 0);

        /*  Sector number tests  */
        ASSERT(GetSectorNumber(vec3i(-TILES_PER_SECTOR_X,   -TILES_PER_SECTOR_Y , -TILES_PER_SECTOR_Z ))    == vec3i(-1, -1, -1));
        ASSERT(GetSectorNumber(vec3i(-1,                    -1,                 -1))                        == vec3i(-1, -1, -1));
        ASSERT(GetSectorNumber(vec3i(0,                     0,                  0))                         == vec3i( 0,  0,  0));
        ASSERT(GetSectorNumber(vec3i(TILES_PER_SECTOR_X-1,  TILES_PER_SECTOR_Y-1, TILES_PER_SECTOR_Z-1))    == vec3i( 0,  0,  0));
        ASSERT(GetSectorNumber(vec3i(TILES_PER_SECTOR_X  ,  TILES_PER_SECTOR_Y  , TILES_PER_SECTOR_Z  ))    == vec3i( 1,  1,  1));

        /*  tile index tests  */
        ASSERT(GetBlockRelativeTileIndex(vec3i(-1, -1, -1)) == vec3i(BLOCK_SIZE_X-1, BLOCK_SIZE_Y-1, BLOCK_SIZE_Z-1));
        ASSERT(GetBlockRelativeTileIndex(vec3i(TILES_PER_BLOCK_X-1,  TILES_PER_BLOCK_Y-1,  TILES_PER_BLOCK_Z-1)) == vec3i(BLOCK_SIZE_X-1, BLOCK_SIZE_Y-1, BLOCK_SIZE_Z-1));
        ASSERT(GetBlockRelativeTileIndex(vec3i( 0,  0,  0)) == vec3i(0, 0, 0));
        ASSERT(GetBlockRelativeTileIndex(vec3i( TILES_PER_BLOCK_X  ,  TILES_PER_BLOCK_Y  ,  TILES_PER_BLOCK_Z  )) == vec3i(0, 0, 0));

        /*  Block index tests  */
        ASSERT(GetChunkRelativeBlockIndex(vec3i(-2,                    -2,                 -2))                == vec3i(CHUNK_SIZE_X-1, CHUNK_SIZE_Y-1, CHUNK_SIZE_Z-1));
        ASSERT(GetChunkRelativeBlockIndex(vec3i(-1,                    -1,                 -1))                == vec3i(CHUNK_SIZE_X-1, CHUNK_SIZE_Y-1, CHUNK_SIZE_Z-1));
        ASSERT(GetChunkRelativeBlockIndex(vec3i( 0,                    0,                  0))                 == vec3i(0, 0, 0));
        ASSERT(GetChunkRelativeBlockIndex(vec3i( 1,                    2,                  3))                 == vec3i(0, 0, 0));
        ASSERT(GetChunkRelativeBlockIndex(vec3i( TILES_PER_BLOCK_X,    TILES_PER_BLOCK_Y,  TILES_PER_BLOCK_Z)) == vec3i(1, 1, 1));
        ASSERT(GetChunkRelativeBlockIndex(vec3i( TILES_PER_CHUNK_X-1,    TILES_PER_CHUNK_Y-1,  TILES_PER_CHUNK_Z-1)) == vec3i(CHUNK_SIZE_X-1, CHUNK_SIZE_Y-1, CHUNK_SIZE_Z-1));

        /*  Chunk index tests  */
        ASSERT(GetSectorRelativeChunkIndex(vec3i(-2,                    -2,                 -2))                == vec3i(SECTOR_SIZE_X-1, SECTOR_SIZE_Y-1, SECTOR_SIZE_Z-1));
        ASSERT(GetSectorRelativeChunkIndex(vec3i(-1,                    -1,                 -1))                == vec3i(SECTOR_SIZE_X-1, SECTOR_SIZE_Y-1, SECTOR_SIZE_Z-1));
        ASSERT(GetSectorRelativeChunkIndex(vec3i( 0,                    0,                  0))                 == vec3i(0, 0, 0));
        ASSERT(GetSectorRelativeChunkIndex(vec3i( 1,                    2,                  3))                 == vec3i(0, 0, 0));
        ASSERT(GetSectorRelativeChunkIndex(vec3i( TILES_PER_CHUNK_X,    TILES_PER_CHUNK_Y,  TILES_PER_CHUNK_Z)) == vec3i(1, 1, 1));


        /*  Block world position, where block start in world, tile-counted  */
        ASSERT(GetBlockWorldPosition(vec3i(-1, -1, -1)) == vec3i(-TILES_PER_BLOCK_X, -TILES_PER_BLOCK_Y, -TILES_PER_BLOCK_Z));
        ASSERT(GetBlockWorldPosition(vec3i( 0,  0,  0)) == vec3i(0, 0, 0));
        ASSERT(GetBlockWorldPosition(vec3i( TILES_PER_BLOCK_X,  TILES_PER_BLOCK_Y,  TILES_PER_BLOCK_Z)) == vec3i(TILES_PER_BLOCK_X, TILES_PER_BLOCK_Y, TILES_PER_BLOCK_Z));



        int x[5][5][5];
        memset(x,0,sizeof x);
        RangeFromTo range(0,5,0,5,0,5);
        foreach (it, range) {
            auto p = *it;
            x[p.X][p.Y][p.Z] = 1;
        }
        auto xx = &x[0][0][0];
        for (int i = 0; i < (sizeof x/sizeof x[0]); i += 1) {
            int j = sizeof x;
            if (xx[i] != 1) {
                printf("Something terrible! %d\n", xx[i]);
                BREAKPOINT;
            }
        }
    }
}


#pragma once

#include "include.h"
#include "Tile.h"

#define BLOCK_SIZE_X (8)
#define BLOCK_SIZE_Y (8)
#define BLOCK_SIZE_Z (8)

#define TILES_PER_BLOCK_X   (BLOCK_SIZE_X)
#define TILES_PER_BLOCK_Y   (BLOCK_SIZE_Y)
#define TILES_PER_BLOCK_Z   (BLOCK_SIZE_Z)


#define BLOCK_UNSEEN    (1<<0)
#define BLOCK_AIR       (1<<1)

class Block
{
private:

   //Keep position of block like this or should instance above keep block position?
   iVec3  m_worldPos; //Position of (upper left front?? derp) corner?

   /* Really make this private? */
   Tile  m_tiles[BLOCK_SIZE_X][BLOCK_SIZE_Y][BLOCK_SIZE_Z];

   u8    m_flags;

   iVec3 getRelativeTilePosition(const iVec3 &tilePosition);

public:
   Block(void);
   ~Block(void);

   void getTile(const iVec3 &relativeTilePosition, Tile &outTile);
   void setTile(const iVec3 &relativeTilePosition, const Tile& tile);

};

typedef Block *BlockPtr;



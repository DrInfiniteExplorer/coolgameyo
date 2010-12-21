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
   vec3i  m_worldPos; //Position of (upper left front?? derp) corner?

   /* Really make this private? */
   Tile  m_tiles[BLOCK_SIZE_X][BLOCK_SIZE_Y][BLOCK_SIZE_Z];

   u8    m_flags;

   vec3i getRelativeTilePosition(const vec3i &tilePosition);

public:
   Block(void);
   ~Block(void);

   Tile getTile(const vec3i &relativeTilePosition);
   void setTile(const vec3i &relativeTilePosition, const Tile& tile);

};

typedef Block *BlockPtr;



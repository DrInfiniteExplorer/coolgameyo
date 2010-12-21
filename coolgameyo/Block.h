#pragma once

#include "include.h"
#include "Tile.h"

class WorldGenerator;

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
   vec3i m_blockPosition;

public:
   Block(void);
   ~Block(void);

   void generateBlock(const vec3i &tilePos, WorldGenerator *pWorldGen);

   Tile getTile(const vec3i &relativeTilePosition);
   void setTile(const vec3i &relativeTilePosition, const Tile& tile);

   vec3i getPosition() const{
       return m_blockPosition;
   }

   bool isSeen() const{
       return GetFlag(m_flags, BLOCK_UNSEEN) == 0;
   }

   bool isAir() const{
       return GetFlag(m_flags, BLOCK_AIR) != 0;
   }

   void render(IVideoDriver *pDriver);

};

typedef Block *BlockPtr;



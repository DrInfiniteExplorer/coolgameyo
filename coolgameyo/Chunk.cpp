#include "Chunk.h"
#include "Util.h"

Chunk::Chunk(void)
{
}


Chunk::~Chunk(void)
{
}


Tile Chunk::getTile(const vec3i tilePos){
   vec3i blockPos = GetChunkRelativeBlockPosition(tilePos);

   /* Keep cache of last 2 indexed blocks? */

   BlockPtr pBlock = m_pBlocks[blockPos.X][blockPos.Y][blockPos.Z];
   if(pBlock){
      return pBlock->getTile(tilePos);
   }
   BREAKPOINT; //huh?
}


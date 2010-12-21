#include "Chunk.h"


Chunk::Chunk(void)
{
}


Chunk::~Chunk(void)
{
}


vec3i Chunk::getBlockPos(const vec3i &tilePos){
   static_assert(TILES_PER_BLOCK_X == (1<<(3)), "Derp a herp");
   static_assert(TILES_PER_BLOCK_Y == (1<<(3)), "Derp a herp");
   static_assert(TILES_PER_BLOCK_Z == (1<<(3)), "Derp a herp");

   return vec3i(
      tilePos.X>>3,
      tilePos.Y>>3,
      tilePos.Z>>3);
}

vec3i Chunk::getRelativeBlockPos(const vec3i &tilePos){
   vec3i blockPos = getBlockPos(tilePos);

   static_assert(0x00000007 == (CHUNK_SIZE_X-1), "Merp!");
   static_assert(0x00000007 == (CHUNK_SIZE_Y-1), "Merp!");
   static_assert(0x00000003 == (CHUNK_SIZE_Z-1), "Merp!");

   blockPos.X &= 0x00000007;
   blockPos.Y &= 0x00000007;
   blockPos.Z &= 0x00000003;

/*
   blockPos.X %= BLOCK_SIZE_X;
   blockPos.Y %= BLOCK_SIZE_Y;
   blockPos.Z %= BLOCK_SIZE_Z;
*/
   return blockPos;
}


void Chunk::getTile(const vec3i tilePos, Tile &outTile){
   vec3i blockPos = getRelativeBlockPos(tilePos);

   /* Keep cache of last 2 indexed blocks? */

   BlockPtr pBlock = m_pBlocks[blockPos.X][blockPos.Y][blockPos.Z];
   if(pBlock){
      pBlock->getTile(tilePos, outTile);
      return;
   }

}


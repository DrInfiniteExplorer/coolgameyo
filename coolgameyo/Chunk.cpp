#include "Chunk.h"


Chunk::Chunk(void)
{
}


Chunk::~Chunk(void)
{
}


iVec3 Chunk::GetBlockPos(const iVec3 &tilePos){
   static_assert(TILES_PER_BLOCK_X == (1<<(3)), "Derp a herp");
   static_assert(TILES_PER_BLOCK_Y == (1<<(3)), "Derp a herp");
   static_assert(TILES_PER_BLOCK_Z == (1<<(3)), "Derp a herp");

   return iVec3(
      tilePos.X>>3,
      tilePos.Y>>3,
      tilePos.Z>>3);
}

iVec3 Chunk::GetRelativeBlockPos(const iVec3 &tilePos){
   iVec3 blockPos = GetBlockPos(tilePos);

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


void Chunk::GetTile(const iVec3 tilePos, Tile &outTile){
   iVec3 blockPos = GetRelativeBlockPos(tilePos);

   /* Keep cache of last 2 indexed blocks? */

   BlockPtr pBlock = m_pBlocks[blockPos.X][blockPos.Y][blockPos.Z];
   if(pBlock){
      pBlock->GetTile(tilePos, outTile);
      return;
   }

}


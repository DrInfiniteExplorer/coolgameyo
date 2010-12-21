#include "Sector.h"


Sector::Sector(void)
{
   memset(m_pChunks, 0, sizeof(m_pChunks));
}


Sector::~Sector(void)
{
}

iVec3 Sector::GetChunkPos(const iVec3 &tilePos){
   static_assert(TILES_PER_CHUNK_X == (1<<(6)), "Derp a herp");
   static_assert(TILES_PER_CHUNK_Y == (1<<(6)), "Derp a herp");
   static_assert(TILES_PER_CHUNK_Z == (1<<(5)), "Derp a herp");

   return iVec3(
      tilePos.X>>6,
      tilePos.Y>>6,
      tilePos.Z>>5);

}



void Sector::GetTile(const iVec3 &tilePos, Tile &outTile){
   iVec3 chunkPos = GetChunkPos(tilePos);
   //Make relative blargh blargh blargh
   chunkPos.X %= SECTOR_SIZE_X;
   chunkPos.Y %= SECTOR_SIZE_Y;
   chunkPos.Z %= SECTOR_SIZE_Z;

   /* Keep cache of last 2 indexed chunks? */

   ChunkPtr pChunk = m_pChunks[chunkPos.X][chunkPos.Y][chunkPos.Z];
   if(pChunk){
      pChunk->GetTile(tilePos, outTile);
      return;
   }
   
   /* We got here. Means that the tile resides in a sparse chunk. */
   /* What to do then? We should keep track of why a chunk is sparse. */
   /* If the chunk is all air; return air constant thing */
   /* Also think and reason about why chunks may want to be sparse */

   printf("see above comments etc\n");
   BREAKPOINT;
}



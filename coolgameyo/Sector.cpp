#include "Sector.h"
#include "Util.h"

Sector::Sector(void)
{
   memset(m_pChunks, 0, sizeof(m_pChunks));
}


Sector::~Sector(void)
{
}



Tile Sector::getTile(const vec3i &tilePos){
   vec3i chunkPos = GetChunkPosition(tilePos);
   //Make relative blargh blargh blargh
   chunkPos.X %= SECTOR_SIZE_X;
   chunkPos.Y %= SECTOR_SIZE_Y;
   chunkPos.Z %= SECTOR_SIZE_Z;

   /* Keep cache of last 2 indexed chunks? */

   ChunkPtr pChunk = m_pChunks[chunkPos.X][chunkPos.Y][chunkPos.Z];
   if(pChunk){
      return pChunk->getTile(tilePos);
   }
   
   /* We got here. Means that the tile resides in a sparse chunk. */
   /* What to do then? We should keep track of why a chunk is sparse. */
   /* If the chunk is all air; return air constant thing */
   /* Also think and reason about why chunks may want to be sparse */

   printf("see above comments etc\n");
   BREAKPOINT;
}



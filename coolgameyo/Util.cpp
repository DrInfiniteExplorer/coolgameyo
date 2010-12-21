#include "Util.h"





vec3i GetBlockRelativeTilePosition  (const vec3i &tilePosition){
   static_assert(0x7 == TILES_PER_BLOCK_X-1, "Derp");
   static_assert(0x7 == TILES_PER_BLOCK_X-1, "Derp");
   static_assert(0x7 == TILES_PER_BLOCK_X-1, "Derp");

   return vec3i(
      tilePosition.X & 0x7,
      tilePosition.Y & 0x7,
      tilePosition.Z & 0x7
      );

/*
   return vec3i(
      tilePosition.X % BLOCK_SIZE_X,
      tilePosition.Y % BLOCK_SIZE_Y,
      tilePosition.Z % BLOCK_SIZE_Z
   );
*/
}

vec3i GetChunkRelativeBlockPosition (const vec3i &tilePosition){

    return vec3i(
          (tilePosition.X / TILES_PER_BLOCK_X) % CHUNK_SIZE_X,
          (tilePosition.Y / TILES_PER_BLOCK_Y) % CHUNK_SIZE_Y,
          (tilePosition.Z / TILES_PER_BLOCK_Z) % CHUNK_SIZE_Z
      );
}

vec3i GetSectorRelativeChunkPosition(const vec3i &tilePosition){
    return vec3i(
          (tilePosition.X / TILES_PER_CHUNK_X) % SECTOR_SIZE_X,
          (tilePosition.Y / TILES_PER_CHUNK_Y) % SECTOR_SIZE_Y,
          (tilePosition.Z / TILES_PER_CHUNK_Z) % SECTOR_SIZE_Z
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







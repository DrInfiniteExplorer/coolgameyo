#pragma once

#include "include.h"
#include "Chunk.h"

#define SECTOR_SIZE_X    (8)
#define SECTOR_SIZE_Y    (8)
#define SECTOR_SIZE_Z    (2)

#define TILES_PER_SECTOR_X   (SECTOR_SIZE_X * TILES_PER_CHUNK_X)
#define TILES_PER_SECTOR_Y   (SECTOR_SIZE_Y * TILES_PER_CHUNK_Y)
#define TILES_PER_SECTOR_Z   (SECTOR_SIZE_Z * TILES_PER_CHUNK_Z)


#define  SECTOR_AIR     (1<<0)


class Sector
{
private:

   u8       m_flags;
   ChunkPtr m_pChunks[SECTOR_SIZE_X][SECTOR_SIZE_Y][SECTOR_SIZE_Z];

public:
    Sector(void);
    virtual ~Sector(void);

   Tile getTile(const vec3i &tilePos);

   
};

#pragma once

#include "include.h"
#include "Chunk.h"

class WorldGenerator;

#define SECTOR_SIZE_X    (8)
#define SECTOR_SIZE_Y    (8)
#define SECTOR_SIZE_Z    (2)

#define CHUNKS_PER_SECTOR (SECTOR_SIZE_X * SECTOR_SIZE_Y * SECTOR_SIZE_Z)

#define TILES_PER_SECTOR_X   (SECTOR_SIZE_X * TILES_PER_CHUNK_X)
#define TILES_PER_SECTOR_Y   (SECTOR_SIZE_Y * TILES_PER_CHUNK_Y)
#define TILES_PER_SECTOR_Z   (SECTOR_SIZE_Z * TILES_PER_CHUNK_Z)


#define  SECTOR_AIR     (1<<0)
#define  SECTOR_UNSEEN  (1<<1)

#define NOCHUNK     (0)     /*  Magic pointer defines!!  */
#define AIRCHUNK    (1)

#define CHUNK_SPARSE(X)         (u32(X) == AIRCHUNK)
#define CHUNK_VISIBLE(X)        (u32(X) > AIRCHUNK)

class Sector
{
private:

    u8       m_chunkCount;
    u8       m_flags;
    ChunkPtr m_pChunks[SECTOR_SIZE_X][SECTOR_SIZE_Y][SECTOR_SIZE_Z];

public:
    Sector(void);
    ~Sector(void);

    /* Used by rendering for example */
    ChunkPtr* lockChunks();
    void unlockChunks(ChunkPtr *pChunks);

    void generateBlock(const vec3i &tilePos, WorldGenerator *pWorldGen);

    Tile getTile(const vec3i &tilePos);

    bool isAir() const{
        return m_chunkCount == CHUNKS_PER_SECTOR &&
            GetFlag(m_flags, SECTOR_AIR);
    }
   
};


/* Eventually put this into a sector-handling class? */
typedef class std::map<u32, Sector*>         SectorZMap;
typedef class std::map<vec2i, SectorZMap*>   SectorXYMap;
typedef class std::vector<Sector*>           SectorList;



#pragma once

#include "include.h"
#include "Chunk.h"

#include "Unit.h"

class WorldGenerator;

const s32 SECTOR_SIZE_X =   4;
const s32 SECTOR_SIZE_Y =   4;
const s32 SECTOR_SIZE_Z =   2;

const s32 CHUNKS_PER_SECTOR =   SECTOR_SIZE_X * SECTOR_SIZE_Y * SECTOR_SIZE_Z;

const s32 TILES_PER_SECTOR_X=   SECTOR_SIZE_X * TILES_PER_CHUNK_X;
const s32 TILES_PER_SECTOR_Y=   SECTOR_SIZE_Y * TILES_PER_CHUNK_Y;
const s32 TILES_PER_SECTOR_Z=   SECTOR_SIZE_Z * TILES_PER_CHUNK_Z;


#define  SECTOR_AIR     (1<<0)
#define  SECTOR_UNSEEN  (1<<1)

#define NOCHUNK     (0)     /*  Magic pointer defines!!  */
#define AIRCHUNK    (1)

#define CHUNK_SPARSE(X)         (u32(X) == AIRCHUNK)
#define CHUNK_VISIBLE(X)        (u32(X) > AIRCHUNK)

class Sector
{
private:

    int      m_chunkCount;
    u8       m_flags;
    ChunkPtr m_pChunks[SECTOR_SIZE_X][SECTOR_SIZE_Y][SECTOR_SIZE_Z];

    std::unordered_set<Unit*> m_activeUnits;
    int m_activityCount;

public:
    Sector(void);
    ~Sector(void);

    /* Used by rendering for example */
    ChunkPtr* lockChunks();
    void unlockChunks(ChunkPtr *pChunks);

    void generateBlock(const vec3i tilePos, WorldGenerator *pWorldGen);

    Tile getTile(const vec3i tilePos);
    void setTile(vec3i tilePos, const Tile newTile);

    Block getBlock(vec3i tilePos);
    void setBlock(vec3i tilePos, Block newBlock);

    void addUnit(Unit* u)
    {
        m_activeUnits.insert(u);
    }
    void incCount()
    {
        m_activityCount += 1;
    }

    bool isAir() const
    {
        return m_chunkCount == CHUNKS_PER_SECTOR &&
            GetFlag(m_flags, SECTOR_AIR);
    }
   
};


/* Eventually put this into a sector-handling class? */
typedef std::map<u32, Sector*>         SectorZMap;
typedef std::map<vec2i, SectorZMap*>   SectorXYMap;
typedef std::vector<Sector*>           SectorList;



#pragma once

#include "include.h"
#include "Block.h"

#include "Unit.h"

class WorldGenerator;

const s32 SECTOR_SIZE_X = 16;
const s32 SECTOR_SIZE_Y = 16;
const s32 SECTOR_SIZE_Z = 4;

const s32 BLOCKS_PER_SECTOR = SECTOR_SIZE_X * SECTOR_SIZE_Y * SECTOR_SIZE_Z;

const s32 TILES_PER_SECTOR_X = SECTOR_SIZE_X * TILES_PER_BLOCK_X;
const s32 TILES_PER_SECTOR_Y = SECTOR_SIZE_Y * TILES_PER_BLOCK_Y;
const s32 TILES_PER_SECTOR_Z = SECTOR_SIZE_Z * TILES_PER_BLOCK_Z;

class Sector
{
private:

    vec3i    m_pos;
    vec3i    m_sectorPos;

    int      m_blockCount;
    u8       m_flags;
    Block    m_blocks[SECTOR_SIZE_X][SECTOR_SIZE_Y][SECTOR_SIZE_Z];

    std::unordered_set<Unit*> m_activeUnits;
    int m_activityCount;

public:
    Sector(vec3i pos);
    ~Sector(void);

    vec3i getPos() { return m_pos; }
    vec3i getSectorPos() { return m_sectorPos; }

    /* Used by rendering for example */
    Block* lockBlocks();
    void unlockBlocks(Block *blocks);

    void generateBlock(const vec3i tilePos, WorldGenerator *pWorldGen);

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
};

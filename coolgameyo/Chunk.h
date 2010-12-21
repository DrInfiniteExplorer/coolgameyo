#pragma once


#include "include.h"
#include "Block.h"

class WorldGenerator;

#define CHUNK_SIZE_X    (4)
#define CHUNK_SIZE_Y    (4)
#define CHUNK_SIZE_Z    (4)

#define BLOCKS_PER_CHUNK (CHUNK_SIZE_X * CHUNK_SIZE_Y * CHUNK_SIZE_Z)

#define TILES_PER_CHUNK_X   (CHUNK_SIZE_X * BLOCK_SIZE_X)
#define TILES_PER_CHUNK_Y   (CHUNK_SIZE_Y * BLOCK_SIZE_Y)
#define TILES_PER_CHUNK_Z   (CHUNK_SIZE_Z * BLOCK_SIZE_Z)

#define CHUNK_AIR       (1<<0)
#define CHUNK_UNSEEN    (1<<1)

#define NOBLOCK     (0)
#define AIRBLOCK    (1)
#define BLOCK_SPARSE(X) (u32(X)==AIRBLOCK)
#define BLOCK_OK(X)     (u32(X)>AIRBLOCK)

class Chunk
{
private:

    BlockPtr    m_pBlocks[CHUNK_SIZE_X][CHUNK_SIZE_Y][CHUNK_SIZE_Z];

    u8          m_flags;
    u8          m_blockCount;

public:
    Chunk(void);
    ~Chunk(void);

    BlockPtr* lockBlocks();
    void unlockBlocks(BlockPtr* pBlocks);

    void generateBlock(const vec3i &tilePos, WorldGenerator *pWorldGen);

    Tile getTile(const vec3i &tilePos);

    bool isSeen() const{
        return GetFlag(m_flags, CHUNK_UNSEEN) == 0;
    }
    bool isAir() const{
        return m_blockCount == BLOCKS_PER_CHUNK &&
            GetFlag(m_flags, CHUNK_AIR) != 0;
    }

};

typedef Chunk *ChunkPtr;

#pragma once


#include "include.h"
#include "Block.h"

class WorldGenerator;


const s32 CHUNK_SIZE_X  =   4;
const s32 CHUNK_SIZE_Y  =   4;
const s32 CHUNK_SIZE_Z  =   2;

const s32 BLOCKS_PER_CHUNK  =   CHUNK_SIZE_X * CHUNK_SIZE_Y * CHUNK_SIZE_Z;

const s32 TILES_PER_CHUNK_X =  CHUNK_SIZE_X * TILES_PER_BLOCK_X;
const s32 TILES_PER_CHUNK_Y =  CHUNK_SIZE_Y * TILES_PER_BLOCK_Y;
const s32 TILES_PER_CHUNK_Z =  CHUNK_SIZE_Z * TILES_PER_BLOCK_Z;

#define CHUNK_AIR       (1<<0)
#define CHUNK_UNSEEN    (1<<1)

#define NOBLOCK     (0)
#define AIRBLOCK    (1)

class Chunk
{
private:

    Block       m_blocks[CHUNK_SIZE_X][CHUNK_SIZE_Y][CHUNK_SIZE_Z];

    u8          m_flags;
    int         m_blockCount;

public:
    Chunk(void);
    ~Chunk(void);

    Block* lockBlocks();
    void unlockBlocks(Block* pBlocks);

    void generateBlock(const vec3i &tilePos, WorldGenerator *pWorldGen);

    Tile getTile(const vec3i tilePos);
    void setTile(vec3i tilePos, const Tile newTile);
    
    Block getBlock(vec3i tilePos);
    void setBlock(vec3i tilePos, Block newBlock);

    bool isSeen() const{
        return GetFlag(m_flags, CHUNK_UNSEEN) == 0;
    }
    bool isAir() const{
        return m_blockCount == BLOCKS_PER_CHUNK &&
            GetFlag(m_flags, CHUNK_AIR) != 0;
    }

    void writeTo(std::function<void(void*,size_t)> f);
    size_t readFrom(void* ptr, size_t size);
};

typedef Chunk *ChunkPtr;

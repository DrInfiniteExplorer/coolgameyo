#pragma once

#include "include.h"
#include "Tile.h"

class WorldGenerator;

//#define BLOCK_SIZE_X (8)
const s32 BLOCK_SIZE_X  =   8;
const s32 BLOCK_SIZE_Y  =   8;
const s32 BLOCK_SIZE_Z  =   8;


const s32 TILES_PER_BLOCK_X   = BLOCK_SIZE_X;
const s32 TILES_PER_BLOCK_Y   = BLOCK_SIZE_Y;
const s32 TILES_PER_BLOCK_Z   = BLOCK_SIZE_Z;
const s32 TILES_PER_BLOCK     = TILES_PER_BLOCK_X * TILES_PER_BLOCK_Y * TILES_PER_BLOCK_Z;


#define BLOCK_SEEN      (1<<0)
#define BLOCK_SPARSE    (1<<1)
#define BLOCK_DIRTY     (1<<6)      //Set when we want to create/update VBO.
#define BLOCK_VALID     (1<<7) 

struct BlockData;
class Block
{
private:
    BlockData       *m_tiles;
    u8               m_flags;

    u16              m_idxCnt; //For VBO-usage and stuff
    u32              m_VBO[2];

    vec3i            m_pos;
public:
    u16              type; // maps to E_TILE_TYPE in case of isSparse()

    vec3i   getPosition() const
    {
        return m_pos;
    }

    static Block alloc();
    static void free(Block block);
    static bool SameTileMemory(Block a, Block b){
        return a.m_tiles == b.m_tiles;
    }

    static Block generateBlock(const vec3i tilePos, WorldGenerator *pWorldGen);

    Block();
    ~Block();

    Tile getTile(const vec3i relativeTilePosition);
    void setTile(const vec3i relativeTilePosition, const Tile tile);

    void render(IVideoDriver *pDriver);

    u32* getVBO(u16 &outIdxCnt)
    {
        outIdxCnt = m_idxCnt;
        return m_VBO;
    }
    bool isDirty() const
    {
        return GetFlag(m_flags, BLOCK_DIRTY) != 0;
    }
    void setClean(unsigned short idxCnt){
        ClearFlag(m_flags, BLOCK_DIRTY);
        m_idxCnt = idxCnt;
    }

    int isValid()  const { return m_flags & BLOCK_VALID;  }
    int isSparse() const { return m_flags & BLOCK_SPARSE; }
    int isSeen()   const { return m_flags & BLOCK_SEEN;   }
    void setSeen(bool seen=true) { SetFlag(m_flags, BLOCK_SEEN, seen); }

    int isVisible() const { return GetFlag(m_flags, BLOCK_SPARSE) == 0;  }

    static Block AIR_BLOCK() {
        Block b;
        SetFlag(b.m_flags, BLOCK_VALID | BLOCK_SPARSE);
        b.type = ETT_AIR;
        return b;
    }


    void writeTo(std::function<void(void*,size_t)> f);
    size_t readFrom(void* ptr, size_t size);
};

inline Block INVALID_BLOCK() {
    Block b;
    return b;
}

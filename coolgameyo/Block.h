#pragma once

#include "include.h"
#include "Tile.h"

class WorldGenerator;

#define BLOCK_SIZE_X (8)
#define BLOCK_SIZE_Y (8)
#define BLOCK_SIZE_Z (8)

#define TILES_PER_BLOCK_X   (BLOCK_SIZE_X)
#define TILES_PER_BLOCK_Y   (BLOCK_SIZE_Y)
#define TILES_PER_BLOCK_Z   (BLOCK_SIZE_Z)


#define BLOCK_SEEN    (1<<0)
#define BLOCK_AIR     (1<<1)
#define BLOCK_SPARSE  (1<<1)
#define BLOCK_VALID   (1<<7) 

struct BlockData;

class Block
{
private:
    BlockData* tiles;
    u8 flags;

public:
    
    vec3i pos;

    static Block alloc();
    static void free(Block block);

    static Block generateBlock(const vec3i tilePos, WorldGenerator *pWorldGen);

    Block();
    ~Block();

    Tile getTile(const vec3i relativeTilePosition);
    void setTile(const vec3i relativeTilePosition, const Tile tile);

    void render(IVideoDriver *pDriver);

    int valid()    const { return flags & BLOCK_VALID;  }
    int isSparse() const { return flags & BLOCK_SPARSE; }
    int isAir()    const { return flags & BLOCK_AIR;    }
    int isSeen()   const { return flags & BLOCK_SEEN;   }

    static Block AIR_BLOCK() {
        Block b;
        b.flags |= BLOCK_VALID | BLOCK_AIR;
        return b;
    }
};


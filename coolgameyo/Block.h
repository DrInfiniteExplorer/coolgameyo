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


#define BLOCK_UNSEEN    (1<<0)
#define BLOCK_AIR       (1<<1)

class Block
{
private:

    /* Really make this private? */
    Tile  m_tiles[BLOCK_SIZE_X][BLOCK_SIZE_Y][BLOCK_SIZE_Z];

    void* operator new(size_t) { throw 2; } // NOT VALID LOL
    void operator delete(void*, size_t) { throw 2; } // NOT VALID LOL
    void* operator new(size_t size, void* place)
    {
        assert (size == sizeof Block);
        return place;
    }
public:

    static Block* alloc();
    static void free(Block* block, bool drop=false);

    Block();
    ~Block();

    void generateBlock(const vec3i tilePos, WorldGenerator *pWorldGen, bool& should_i_become_air);

    Tile getTile(const vec3i relativeTilePosition);
    void setTile(const vec3i relativeTilePosition, const Tile tile);

    void render(IVideoDriver *pDriver);

};

typedef Block *BlockPtr;
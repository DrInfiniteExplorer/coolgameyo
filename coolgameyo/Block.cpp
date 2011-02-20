#include "Block.h"
#include "Util.h"
#include "WorldGenerator.h"

struct BlockData {
    Tile tiles[BLOCK_SIZE_X][BLOCK_SIZE_Y][BLOCK_SIZE_Z];
};

namespace Allocator
{
    struct Link
    {
        BlockData* mem;
        Link* next;
        size_t size;

        size_t index;
        std::vector<bool> freeBits;

        Link(size_t size, Link* lst)
            : mem((BlockData*)AllocateBlob(size)), next(lst), size(size),
            index(0), freeBits(size, false)
        {
            if (!mem) {
                printf("Memory allocation seems to have failed :(\n");
                BREAKPOINT;
            }
        }
    };

    static_assert(sizeof BlockData == 4096, "Cry cry cry");

    TLS Link* linklist = 0;

    static BlockData* getMem()
    {
        auto link = linklist;
        while (link) {
            for (size_t k = 0; k < link->size; k += 1) {
                auto i = link->index;
                link->index = (link->index+1) % link->size;
                if (!link->freeBits[i]) {
                    link->freeBits[i] = true;
                    return ((BlockData*)link->mem) + i;
                }
            }
            link = link->next;
        }
        // No free blob found! Time to allocate!

        linklist = new Link(64, linklist);
        return getMem(); // hee
    }
    void returnMem(BlockData* mem)
    {
        Link* link = linklist;
        while (link) {
            size_t diff = mem - link->mem;
            if (diff < link->size) {
                // woo!
                link->freeBits[diff] = false;
                link->index = diff;
                return;
            }
            link = link->next;
        }
        printf("Tried to return something.. blah blah\n");
        BREAKPOINT;
    }
}

Block Block::alloc()
{
    auto mem = Allocator::getMem();
    memset(mem, 0, sizeof *mem);
    Block ret;
    ret.m_tiles = mem;
    return ret;
}
void Block::free(Block block)
{
    if (block.isValid()) {
        Allocator::returnMem(block.m_tiles);
    }
}


Block::Block() : m_flags(BLOCK_DIRTY), m_idxCnt(0), m_tiles(0)
{
    m_VBO[0] = m_VBO[1] = 0;
}


Block::~Block()
{
}

Block Block::generateBlock(const vec3i tilePos, WorldGenerator *pWorldGen)
{
    vec3i blockPos = GetBlockWorldPosition(tilePos);
    //printf("Generating block @%6d,%5d,%5d\n", blockPos.X, blockPos.Y, blockPos.Z);
    vec3i pos;
    
    Block b = alloc();
    SetFlag(b.m_flags, BLOCK_VALID);
    SetFlag(b.m_flags, BLOCK_DIRTY);
    b.m_pos = blockPos;
    bool any_non_air = false;

    RangeFromTo range(0, BLOCK_SIZE_X, 0, BLOCK_SIZE_Y, 0, BLOCK_SIZE_Z);
    foreach (rel, range) {
        auto RRR = *rel;
        pos = blockPos + RRR;

        Tile t = pWorldGen->getTile(pos);
        b.m_tiles->tiles[RRR.X][RRR.Y][RRR.Z] = t;
                
        if (t.type == ETT_AIR) {
            any_non_air = true;
        }
    }

    if (any_non_air) {
        return b;
    } else {
        free(b);
        return AIR_BLOCK();
    }
}

Tile Block::getTile(const vec3i tilePosition)
{
    if (!isValid()) return INVALID_TILE();

    if (isSparse()) {
        Tile t = {type, 0, TILE_VALID, 0};
        t.setSeen(isSeen() != 0);
        return t;
    }

    /* Remove this sometime? */
    vec3i relativeTilePosition = GetBlockRelativeTileIndex(tilePosition);
    return m_tiles->tiles[relativeTilePosition.X][relativeTilePosition.Y][relativeTilePosition.Z];
}

void Block::setTile(const vec3i tilePosition, const Tile newTile)
{
    assert(isValid()); //Same as line below?
    assert(m_tiles); //Derp a herp; When we fail and try to set a tile in an air block, start thinkging and implementing.

    /* Remove this sometime? */
    vec3i relativeTilePosition = GetBlockRelativeTileIndex(tilePosition);

    bool same = m_tiles->tiles[relativeTilePosition.X][relativeTilePosition.Y][relativeTilePosition.Z] == newTile;
    if(same){
        SetFlag(m_flags, BLOCK_DIRTY);
    }


    m_tiles->tiles[relativeTilePosition.X][relativeTilePosition.Y][relativeTilePosition.Z] = newTile;

    /*  Make improvement like thingy with optimizations and such */

}

void Block::writeTo(std::function<void(void*,size_t)> f)
{
    assert (isValid());

    f(&m_flags, sizeof m_flags);
    f(&m_pos, sizeof m_pos);

    if (isSparse()) return;

    auto t = &m_tiles->tiles[0][0][0];
    for (int i = 0; i < TILES_PER_BLOCK; i += 1) {
        t->writeTo(f);
    }
}

size_t Block::readFrom(void* ptr, size_t size)
{

    auto readsize = sizeof this->m_flags + sizeof this->m_pos;

    if (size < readsize) return 0;

    memcpy(&m_flags, ptr, sizeof m_flags);
    memcpy(&m_pos, ptr, sizeof m_pos);

    if (isSparse()) return readsize;

    m_tiles = Allocator::getMem();

    assert (size >= readsize + sizeof *m_tiles);

    memcpy(m_tiles, ptr, sizeof *m_tiles);

    return readsize + sizeof *m_tiles;
}

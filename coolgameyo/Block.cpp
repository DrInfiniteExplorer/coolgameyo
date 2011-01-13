#include "Block.h"
#include "Util.h"
#include "WorldGenerator.h"

struct BlockData {
    Tile tiles[BLOCK_SIZE_X][BLOCK_SIZE_Y][BLOCK_SIZE_Z];
};

namespace FreeList
{
    enum { max_size = 100 };
    union Link
    {
        char memory[sizeof BlockData];
        Link* next;
    };

    static_assert(sizeof Link == sizeof BlockData, "Cry cry cry");
    static_assert(sizeof BlockData == 4096, "Cry cry cry");

    TLS int size = 0;
    TLS Link* list = 0;

    static void* getMem()
    {
        if (list) {
            void* ret = list;
            list = list->next;
            size -= 1;
            return ret;
        } else {
            // allocate here
            void* ret = AllocatePage();
            assert (ret);
            return ret;
        }
    }
    void returnMem(BlockData* mem)
    {
        if (size >= max_size) {
            // free here
            FreePage(mem);
        } else {
            auto link = (Link*)mem;
            link->next = list;
            list = link;
            size += 1;
        }
    }
}

Block Block::alloc()
{
    void* mem = FreeList::getMem();
    Block ret;
    ret.m_pTiles = (BlockData*)mem;
    return ret;
}
void Block::free(Block block)
{
    FreeList::returnMem(block.m_pTiles);
}


Block::Block() : m_flags(0), m_idxCnt(0), m_pTiles(0)
{
    m_VBO[0] = m_VBO[1] = 0;
}


Block::~Block()
{
}

Block Block::generateBlock(const vec3i tilePos, WorldGenerator *pWorldGen)
{
    vec3i blockPos = GetBlockWorldPosition(tilePos);
    printf("Generating block @%6d,%5d,%5d\n", blockPos.X, blockPos.Y, blockPos.Z);
    vec3i pos;
    
    Block b = alloc();
    SetFlag(b.m_flags, BLOCK_VALID);
    SetFlag(b.m_flags, BLOCK_DIRTY);
    b.m_pos = blockPos;
    bool any_non_air = false;

    for(int x=0;x<BLOCK_SIZE_X;x++){
        pos.X = blockPos.X + x;
        for(int y=0;y<BLOCK_SIZE_Y;y++){
            pos.Y = blockPos.Y + y;
            for(int z=0;z<BLOCK_SIZE_Z;z++){
                pos.Z = blockPos.Z + z;

                Tile t = pWorldGen->getTile(pos);
                b.m_pTiles->tiles[x][y][z] = t;
                
                if(!GetFlag(t.type, ETT_AIR)){
                    any_non_air = true;
                }

            }
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
    assert (isValid());

    if (isAir()) return AIR_TILE();
    if (isSparse()) return SPARSE_TILE();

    /* Remove this sometime? */
    vec3i relativeTilePosition = GetBlockRelativeTileIndex(tilePosition);
    return m_pTiles->tiles[relativeTilePosition.X][relativeTilePosition.Y][relativeTilePosition.Z];
}

void Block::setTile(const vec3i tilePosition, const Tile newTile)
{
    assert(isValid()); //Same as line below?
    assert(m_pTiles); //Derp a herp; When we fail and try to set a tile in an air block, start thinkging and implementing.

    /* Remove this sometime? */
    vec3i relativeTilePosition = GetBlockRelativeTileIndex(tilePosition);

    bool same = m_pTiles->tiles[relativeTilePosition.X][relativeTilePosition.Y][relativeTilePosition.Z] == newTile;
    SetFlag(m_flags, BLOCK_DIRTY, !same);


    m_pTiles->tiles[relativeTilePosition.X][relativeTilePosition.Y][relativeTilePosition.Z] = newTile;

    /*  Make improvement like thingy with optimizations and such */

    SetFlag(m_flags, BLOCK_AIR,     GetFlag(m_flags, BLOCK_AIR)    && (newTile.type == ETT_AIR));
}



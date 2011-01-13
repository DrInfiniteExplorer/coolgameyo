#include "Block.h"
#include "Util.h"
#include "WorldGenerator.h"

namespace FreeList
{
    enum { max_size = 100 };
    union Link
    {
        char memory[sizeof Block];
        Link* next;
    };

    static_assert(sizeof Link == sizeof Block, "Cry cry cry");
    static_assert(sizeof Block == 4096, "Cry cry cry");

    TLS int size = 0;
    TLS Link* list = 0;

    static void* getMemForBlock()
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
    void returnMem(Block* block, bool drop=false)
    {
        if (size >= max_size || drop) {
            free(block);
        } else {
            auto link = (Link*)block;
            link->next = list;
            list = link;
            size += 1;
        }
    }
}

Block* Block::alloc()
{
    void* mem = FreeList::getMemForBlock();
    Block* ret = new (mem) Block();
    return ret;
}
void Block::free(Block* block, bool drop)
{
    block->~Block();
    FreeList::returnMem(block, drop);
}


Block::Block()
{
}


Block::~Block()
{
}

void Block::generateBlock(const vec3i tilePos, WorldGenerator *pWorldGen, bool &should_i_become_air)
{
    vec3i blockPos = GetBlockWorldPosition(tilePos);
    printf("Generating block @ %d\t%d\t%d\n", blockPos.X, blockPos.Y, blockPos.Z);
    vec3i pos;
    Tile t;
    should_i_become_air = false;
    for(int x=0;x<BLOCK_SIZE_X;x++){
        pos.X = blockPos.X + x;
        for(int y=0;y<BLOCK_SIZE_Y;y++){
            pos.Y = blockPos.Y + y;
            for(int z=0;z<BLOCK_SIZE_Z;z++){
                pos.Z = blockPos.Z + z;
                t = pWorldGen->getTile(pos);
                m_tiles[x][y][z] = t;
                if (t.flags & TILE_SPARSE) {
                    should_i_become_air = true;
                }
            }
        }
    }
}

Tile Block::getTile(const vec3i tilePosition){
    /* Remove this sometime? */
    vec3i relativeTilePosition = GetBlockRelativeTileIndex(tilePosition);
    return m_tiles[relativeTilePosition.X][relativeTilePosition.Y][relativeTilePosition.Z];
}

void Block::setTile(const vec3i tilePosition, const Tile newTile){
    /* Remove this sometime? */
    vec3i relativeTilePosition = GetBlockRelativeTileIndex(tilePosition);

    m_tiles[relativeTilePosition.X][relativeTilePosition.Y][relativeTilePosition.Z] = newTile;
}






void Block::render(IVideoDriver *pDriver){
    static aabbox3df box(-0.5f, -0.5f, -0.5f, 0.5f, 0.5f, 0.5f);
    SMaterial mat;
    mat.Lighting = false;
    mat.Wireframe = true;
    pDriver->setMaterial(mat);
    matrix4 matr;
    matr = pDriver->getTransform(ETS_WORLD);
    vec3f blockPos = matr.getTranslation();
    vec3f pos;
    for(int x=0;x<BLOCK_SIZE_X;x++){
        pos.X = blockPos.X + x;
    for(int y=0;y<BLOCK_SIZE_Y;y++){
        pos.Y = blockPos.Y + y;
    for(int z=0;z<BLOCK_SIZE_Z;z++){
        pos.Z = blockPos.Z + z;
        matr.setTranslation(pos);
        pDriver->setTransform(ETS_WORLD, matr);
        pDriver->draw3DBox(box);
    }
    }
    }
}



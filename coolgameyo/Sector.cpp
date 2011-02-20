#include "Sector.h"
#include "Util.h"

Sector::Sector(vec3i sectorPos)
    : m_activityCount(0), m_blockCount(0), m_flags(0), m_sectorPos(sectorPos)
{
   memset(m_blocks, 0, sizeof(m_blocks));
   m_pos = vec3i(sectorPos.X * TILES_PER_SECTOR_X,
       sectorPos.Y * TILES_PER_SECTOR_Y,
       sectorPos.Z * TILES_PER_SECTOR_Z);
}


Sector::~Sector(void)
{
    for(int x=0;x<SECTOR_SIZE_X;x++){
        for(int y=0;y<SECTOR_SIZE_Y;y++){
            for(int z=0;z<SECTOR_SIZE_Z;z++){
                Block::free(m_blocks[x][y][z]);
            }
        }
    }
}

Block* Sector::lockBlocks()
{
    /* Implement mutex or something */
    return &m_blocks[0][0][0];
}
void Sector::unlockBlocks(Block *blocks)
{
    /* Herp a derp */
}


void Sector::generateBlock(const vec3i tilePos, WorldGenerator *worldGen)
{
    auto bp = GetSectorRelativeBlockIndex(tilePos);
    auto block = &m_blocks[bp.X][bp.Y][bp.Z];

    //printf("Generating block at %d %d %d", bp.X, bp.Y, bp.Z);

    assert (!block->isValid());

    *block = Block::generateBlock(tilePos, worldGen);

    static int c = 0;
    if(block->isSparse()){
        if (block->type == ETT_AIR) ++c;
        //printf(" and it is air? %d (%d)\n", block->type == ETT_AIR, c);
    }
    
}

Block Sector::getBlock(vec3i tilePos)
{
    auto bp = GetSectorRelativeBlockIndex(tilePos);
    auto shit = tilePos;
    return m_blocks[bp.X][bp.Y][bp.Z];
}
void Sector::setBlock(vec3i tilePos, Block newBlock)
{
    auto bp = GetSectorRelativeBlockIndex(tilePos);
    auto b = &m_blocks[bp.X][bp.Y][bp.Z];

    if (b->isValid()) { 
        //printf("Replacing block at %d %d %d\n", bp.X, bp.Y, bp.Z);
        if( !Block::SameTileMemory(*b, newBlock)){
            Block::free(*b);
        }
    }
    *b = newBlock;
}

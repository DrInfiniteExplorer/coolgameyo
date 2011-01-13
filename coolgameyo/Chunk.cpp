#include "Chunk.h"
#include "Util.h"

Chunk::Chunk(void)
{
    memset(m_pBlocks, 0, sizeof(m_pBlocks));
    m_flags = CHUNK_AIR | CHUNK_UNSEEN;
    m_blockCount = 0;
}


Chunk::~Chunk(void)
{
    for(int x=0;x<CHUNK_SIZE_X;x++){
    for(int y=0;y<CHUNK_SIZE_Y;y++){
    for(int z=0;z<CHUNK_SIZE_Z;z++){
        auto pBlock = m_pBlocks[x][y][z];
        if (pBlock.block) {
            if (!BLOCK_SPARSE(pBlock.block)) {
                Block::free(pBlock.block, true);
            }
        }
    }}}
}

BlockData* Chunk::lockBlocks(){
    return &m_pBlocks[0][0][0];
}

void Chunk::unlockBlocks(BlockData* pBlocks){
    /* Herp a derp */
}


void Chunk::generateBlock(const vec3i &tilePos, WorldGenerator *pWorldGen){
    vec3i blockPos = GetChunkRelativeBlockIndex(tilePos);
    auto pBlock = m_pBlocks[blockPos.X][blockPos.Y][blockPos.Z];
    if(pBlock.block){
        /*  If we've got a block, then we must've loaded or generated  */
        /*  it already, right?  */
        return;
    }
    m_blockCount++;
    pBlock.pos = GetBlockWorldPosition(tilePos);
    pBlock.block = Block::alloc();
    m_pBlocks[blockPos.X][blockPos.Y][blockPos.Z] = pBlock;

    bool air;
    pBlock.block->generateBlock(tilePos, pWorldGen, air);

    if (air) {
        m_pBlocks[blockPos.X][blockPos.Y][blockPos.Z].flags &= BLOCK_AIR;
        m_pBlocks[blockPos.X][blockPos.Y][blockPos.Z].block = (BlockPtr)AIRBLOCK;
        Block::free(pBlock.block);
        return;
    }

    SetFlag(m_flags, CHUNK_UNSEEN, GetFlag(m_flags, CHUNK_UNSEEN) && !pBlock.isSeen());
    SetFlag(m_flags, CHUNK_AIR,    false);
}


Tile Chunk::getTile(const vec3i &tilePos){
   vec3i blockPos = GetChunkRelativeBlockIndex(tilePos);

   /* Keep cache of last 2 indexed blocks? */

    auto pBlock = m_pBlocks[blockPos.X][blockPos.Y][blockPos.Z];
    if (pBlock.block) {
        if(BLOCK_SPARSE(pBlock.block)){
            return SPARSE_TILE();
        }
        return pBlock.block->getTile(tilePos);
    }
    return INVALID_TILE();
}


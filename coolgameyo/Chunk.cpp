#include "Chunk.h"
#include "Util.h"

Chunk::Chunk(void)
{
    memset(m_blocks, 0, sizeof(m_blocks));
    m_flags = CHUNK_AIR | CHUNK_UNSEEN;
    m_blockCount = 0;
}


Chunk::~Chunk(void)
{
    for(int x=0;x<CHUNK_SIZE_X;x++){
    for(int y=0;y<CHUNK_SIZE_Y;y++){
    for(int z=0;z<CHUNK_SIZE_Z;z++){
        auto pBlock = m_blocks[x][y][z];
        if (pBlock.isValid()) {
            Block::free(pBlock);
        }
    }}}
}

Block* Chunk::lockBlocks(){
    return &m_blocks[0][0][0];
}

void Chunk::unlockBlocks(Block* pBlocks){
    /* Herp a derp */
}


void Chunk::generateBlock(const vec3i &tilePos, WorldGenerator *pWorldGen){
    vec3i blockPos = GetChunkRelativeBlockIndex(tilePos);
    auto block = m_blocks[blockPos.X][blockPos.Y][blockPos.Z];
    if(block.isValid()){
        /*  If we've got a block, then we must've loaded or generated  */
        /*  it already, right?  */
        return;
    }
    m_blockCount++;

    block = Block::generateBlock(tilePos, pWorldGen);
    m_blocks[blockPos.X][blockPos.Y][blockPos.Z] = block;

    SetFlag(m_flags, CHUNK_UNSEEN, GetFlag(m_flags, CHUNK_UNSEEN) && !block.isSeen());
    SetFlag(m_flags, CHUNK_AIR,    false);
}


Tile Chunk::getTile(const vec3i tilePos){
   vec3i blockPos = GetChunkRelativeBlockIndex(tilePos);

   /* Keep cache of last 2 indexed blocks? */

    auto pBlock = m_blocks[blockPos.X][blockPos.Y][blockPos.Z];
    if (pBlock.isValid()) {
        return pBlock.getTile(tilePos);
    }
    return INVALID_TILE();
}


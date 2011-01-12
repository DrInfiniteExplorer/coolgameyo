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
        BlockPtr pBlock = m_pBlocks[x][y][z];
        if(pBlock){
            if(!BLOCK_SPARSE(pBlock)){
                delete pBlock;
            }
        }
    }}}
}

BlockPtr* Chunk::lockBlocks(){
    return &m_pBlocks[0][0][0];
}

void Chunk::unlockBlocks(BlockPtr* pBlocks){
    /* Herp a derp */
}


void Chunk::generateBlock(const vec3i &tilePos, WorldGenerator *pWorldGen){
    vec3i blockPos = GetChunkRelativeBlockIndex(tilePos);
    BlockPtr pBlock = m_pBlocks[blockPos.X][blockPos.Y][blockPos.Z];
    if(pBlock){
        /*  If we've got a block, then we must've loaded or generated  */
        /*  it already, right?  */
        return;
    }
    m_blockCount++;
    pBlock = new Block(GetBlockWorldPosition(tilePos));
    m_pBlocks[blockPos.X][blockPos.Y][blockPos.Z] = pBlock;

    pBlock->generateBlock(tilePos, pWorldGen);

    if(pBlock->isAir()){
        m_pBlocks[blockPos.X][blockPos.Y][blockPos.Z] = (BlockPtr)AIRBLOCK;
        delete pBlock;
        return;
    }

    SetFlag(m_flags, CHUNK_UNSEEN, GetFlag(m_flags, CHUNK_UNSEEN) && !pBlock->isSeen());
    SetFlag(m_flags, CHUNK_AIR,    false);
}


Tile Chunk::getTile(const vec3i &tilePos){
   vec3i blockPos = GetChunkRelativeBlockIndex(tilePos);

   /* Keep cache of last 2 indexed blocks? */

    BlockPtr pBlock = m_pBlocks[blockPos.X][blockPos.Y][blockPos.Z];
    if(pBlock){
        if(BLOCK_SPARSE(pBlock)){
            return SPARSE_TILE();
        }
        return pBlock->getTile(tilePos);
    }
    return INVALID_TILE();
}


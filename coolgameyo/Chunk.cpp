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

void Chunk::setTile(vec3i tilePos, const Tile newTile)
{
    vec3i blockPos = GetChunkRelativeBlockIndex(tilePos);
    auto pBlock = m_blocks[blockPos.X][blockPos.Y][blockPos.Z];
    if (pBlock.isValid()) {
        return pBlock.setTile(tilePos, newTile);
    }
    BREAKPOINT;
}
    
Block Chunk::getBlock(vec3i tilePos)
{
    vec3i blockPos = GetChunkRelativeBlockIndex(tilePos);
    auto pBlock = m_blocks[blockPos.X][blockPos.Y][blockPos.Z];
    return pBlock;
}
void Chunk::setBlock(vec3i tilePos, Block newBlock)
{
    vec3i blockPos = GetChunkRelativeBlockIndex(tilePos);
    m_blocks[blockPos.X][blockPos.Y][blockPos.Z] = newBlock;
}



void Chunk::writeTo(std::function<void(void*,size_t)> f)
{
    f(&m_flags, sizeof m_flags);
    f(&m_blockCount, sizeof m_blockCount);

    auto b = lockBlocks();
    int bc = m_blockCount;
    for (int i = 0; i < BLOCKS_PER_CHUNK; i += 1) {
        if (b->isValid()) {
            b->writeTo(f);
            bc -= 1;
        }
    }
    if (bc != 0) {
        printf("wtf...?");
        BREAKPOINT;
    }
}

size_t Chunk::readFrom(void* ptr, size_t size)
{
    BREAKPOINT;
    return 0;
}
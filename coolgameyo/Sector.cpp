#include "Sector.h"
#include "Util.h"

Sector::Sector(void)
    : m_activityCount(0)
{
   memset(m_pChunks, 0, sizeof(m_pChunks));
   m_chunkCount=0;
   m_flags = SECTOR_AIR | SECTOR_UNSEEN;
}


Sector::~Sector(void)
{
    for(int x=0;x<SECTOR_SIZE_X;x++){
    for(int y=0;y<SECTOR_SIZE_Y;y++){
    for(int z=0;z<SECTOR_SIZE_Z;z++){
        ChunkPtr pChunk = m_pChunks[x][y][z];
        if(pChunk){
            delete pChunk;
        }
    }}}
}

ChunkPtr* Sector::lockChunks()
{
    /* Implement mutex or something */
    return &m_pChunks[0][0][0];
}
void Sector::unlockChunks(ChunkPtr *pChunks)
{
    /* Herp a derp */

}


void Sector::generateBlock(const vec3i tilePos, WorldGenerator *pWorldGen)
{
    vec3i chunkPos = GetSectorRelativeChunkIndex(tilePos);
    ChunkPtr pChunk = m_pChunks[chunkPos.X][chunkPos.Y][chunkPos.Z];
    if(!pChunk){
        pChunk = new Chunk();
        m_pChunks[chunkPos.X][chunkPos.Y][chunkPos.Z] = pChunk;
        m_chunkCount++;
    }

    pChunk->generateBlock(tilePos, pWorldGen);
    if(pChunk->isAir()){
        delete pChunk;
        m_pChunks[chunkPos.X][chunkPos.Y][chunkPos.Z] = (ChunkPtr)AIRCHUNK;
    }

    SetFlag(m_flags, SECTOR_UNSEEN, GetFlag(m_flags, SECTOR_UNSEEN) && !pChunk->isSeen());

    /* DO OPTIMIZATION LIKE RECOGNIZE ALL AIR ETC */
}

Tile Sector::getTile(const vec3i tilePos)
{
    vec3i chunkPos = GetSectorRelativeChunkIndex(tilePos);

    /* Keep cache of last 2 indexed chunks? */

    ChunkPtr pChunk = m_pChunks[chunkPos.X][chunkPos.Y][chunkPos.Z];
    if(pChunk){
        if(CHUNK_SPARSE(pChunk)){
            return INVALID_TILE();
        }
        return pChunk->getTile(tilePos);
    }
   
    /* We got here. Means that the tile resides in a sparse chunk. */
    /* What to do then? We should keep track of why a chunk is sparse. */
    /* If the chunk is all air; return air constant thing */
    /* Also think and reason about why chunks may want to be sparse */
    return INVALID_TILE();
}

void Sector::setTile(vec3i tilePos, const Tile newTile)
{
    // copy paste
    vec3i chunkPos = GetSectorRelativeChunkIndex(tilePos);
    ChunkPtr pChunk = m_pChunks[chunkPos.X][chunkPos.Y][chunkPos.Z];
    if(!pChunk){
        pChunk = new Chunk();
        m_pChunks[chunkPos.X][chunkPos.Y][chunkPos.Z] = pChunk;
        m_chunkCount++;
    }
    // /copy paste

    pChunk->setTile(tilePos, newTile);
}

Block Sector::getBlock(vec3i tilePos)
{
    vec3i chunkPos = GetSectorRelativeChunkIndex(tilePos);
    ChunkPtr pChunk = m_pChunks[chunkPos.X][chunkPos.Y][chunkPos.Z];
    if(!pChunk){ return INVALID_BLOCK(); }

    return pChunk->getBlock(tilePos);
}
void Sector::setBlock(vec3i tilePos, Block newBlock)
{
    vec3i chunkPos = GetSectorRelativeChunkIndex(tilePos);
    ChunkPtr pChunk = m_pChunks[chunkPos.X][chunkPos.Y][chunkPos.Z];
    if(!pChunk){ ASSERT(0); }

    pChunk->setBlock(tilePos, newBlock);
}

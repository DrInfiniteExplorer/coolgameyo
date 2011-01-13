#include "World.h"
#include "Game.h"
#include "Util.h"

World::World(Game *pGame)
   : m_pGame(pGame),
   m_pDriver(pGame->getDevice()->getVideoDriver())
{

    const s32 limit = 32;//BLOCK_SIZE_X*CHUNK_SIZE_X*SECTOR_SIZE_X;
    s32 cnt = 0;
    for (int x = -limit; x<limit; x++) {
        for (int y = -limit; y<limit; y++) {
            for (int z = -limit; z<limit; z++) {
                if (TILE_VISIBLE(getTile(vec3i(x,y,z)))) {
                    cnt++;
                }
            }
        }
    }
    printf("%d\n", cnt);
    printf("%d\n", (2*limit)*(2*limit)*(2*limit));

}


World::~World(void)
{
}

Tile World::loadTileFromDisk(const vec3i &tilePos)
{
    return INVALID_TILE();
}

void World::generateBlock(const vec3i &tilePos)
{
    vec3i sectorPos = GetSectorNumber(tilePos);
    vec2i sectorXY(sectorPos.X, sectorPos.Y);
    auto xy = m_sectors[sectorXY];
    if (!xy) {
        xy = new SectorZMap;
        m_sectors[sectorXY] = xy;
    }
    Sector* pSector = (*xy)[sectorPos.Z];
    if (!pSector) {
        pSector = new Sector();
        (*xy)[sectorPos.Z] = pSector;
        m_sectorList.push_back(pSector);
    }
    pSector->generateBlock(tilePos, &m_worldGen);

    /* DO OPTIMIZATION LIKE CHECKING IF ALL THINGS ARE AIR ETC */

    /* Store to harddrive? schedule it? */
}

//const SectorList& World::getAllSectors(){
const SectorList& World::getAllSectors()
{
    return m_sectorList;
}


void World::render()
{
    /* Implement sector iterator sometime? */
    auto sectorList = getAllSectors();
    foreach (sect, sectorList) {
        /* Culling based on sectors */
        Sector *pSector = *sect;
        ChunkPtr *pChunks = pSector->lockChunks();
        for (int i=0;i<CHUNKS_PER_SECTOR; i++) {
            ChunkPtr pChunk = pChunks[i];
            if(!CHUNK_VISIBLE(pChunk)){
                continue;
            }

            /* At some point, maybe move rendering to chunk-level. :) */

            auto *pBlocks = pChunk->lockBlocks();
            for (int c=0;c<BLOCKS_PER_CHUNK;c++) {
                auto pBlock = pBlocks[c];
                if (!(pBlock.valid())) {
                    continue;
                }

                matrix4 mat;
                vec3i blockPosition = pBlocks[c].pos;
                mat.setTranslation(vec3f(
                    (f32)blockPosition.X,
                    (f32)blockPosition.Y,
                    (f32)blockPosition.Z));
                m_pDriver->setTransform(ETS_WORLD, mat); 
                pBlock.render(m_pDriver);
            }
            pChunk->unlockBlocks(pBlocks);
        }

        pSector->unlockChunks(pChunks);
    }
}


Tile World::getTile(const vec3i tilePos)
{
   /* Speed things up by keeping a cache of the last x indexed sectors? */

    vec3i sectorPos = GetSectorNumber(tilePos);
    Tile returnTile;
    
    vec2i xyPos(sectorPos.X, sectorPos.Y);
    auto iter = m_sectors.find(xyPos);
    if (m_sectors.end() != iter) {
        SectorZMap *zMap = iter->second; // (*iter)->second
        auto iter2 = zMap->find(sectorPos.Z);
        if (zMap->end() != iter2) {
            Sector *pSector = iter2->second;
            returnTile = pSector->getTile(tilePos);
            if (!GetFlag(returnTile.flags, TILE_INVALID)) {
                return returnTile;
            }
        }
    }

    /* May fail, but if it works we're all good */
    returnTile = loadTileFromDisk(tilePos);
    if (GetFlag(returnTile.flags, TILE_INVALID)) {
        //Invalid tile! loading was not successfull! :):):):)
        if (m_pGame->isServer()) {
            generateBlock(tilePos);
            return getTile(tilePos); //Derp a herp!!
        } else {
            /* Send request to sever!! */
            printf("Implement etc\n");
            BREAKPOINT;
        }
    }

    return returnTile;
}

// boring notification functions :(
void World::notifySectorLoad(vec3i sectorPos)
{
    foreach (it, m_listeners) {
        (*it)->notifySectorLoad(sectorPos);
    }
}
void World::notifySectorUnload(vec3i sectorPos)
{
    foreach (it, m_listeners) {
        (*it)->notifySectorUnload(sectorPos);
    }
}
void World::notifyTileChange(vec3i tilePos)
{
    foreach (it, m_listeners) {
        (*it)->notifyTileChange(tilePos);
    }
}

#include "World.h"
#include "Game.h"
#include "Util.h"
#include "Renderer.h"

World::World(Game *pGame)
   : m_pGame(pGame)
{
    m_pRenderer = new Renderer(this, m_pGame->getDevice()->getVideoDriver());

//*
    const s32 limit = 96;//BLOCK_SIZE_X*CHUNK_SIZE_X*SECTOR_SIZE_X;
    const s32 offset = 0;
    s32 cnt = 0;
    for (int x = -limit; x<limit; x++) {
        for (int y = -limit+offset; y<limit+offset; y++) {
            for (int z = -limit; z<limit; z++) {
                Tile t = getTile(vec3i(x,y,z));
                if (TILE_VISIBLE(t) && t.type != ETT_AIR) {
                    cnt++;
                }
            }
        }
    }
    printf("%d of\n", cnt);
    printf("%d\n", (2*limit)*(2*limit)*(2*limit));
/*/
    {
    s32 x =0,
        y =0,
        z =-1;
    getTile(vec3i(x,y,z));
    }
    {
    s32 x =0,
        y =0,
        z =8;
    getTile(vec3i(x,y,z));
    }
//*/
}


World::~World(void)
{
    delete m_pRenderer;
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
    m_pRenderer->preRender();
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
            m_pRenderer->renderChunk(pChunk);
        }

        pSector->unlockChunks(pChunks);
    }
    m_pRenderer->postRender();
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

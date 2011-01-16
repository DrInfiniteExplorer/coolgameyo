#include "World.h"
#include "Game.h"
#include "Util.h"
#include "Renderer.h"

World::World(Game *pGame)
   : m_pGame(pGame)
{
    m_pRenderer = new Renderer(this, m_pGame->getDevice()->getVideoDriver());

//*
    const s32 limit = 64;//BLOCK_SIZE_X*CHUNK_SIZE_X*SECTOR_SIZE_X;
    const s32 offset = 0;

    s32 cnt = 0;
    for (int x = -limit; x<limit; x += BLOCK_SIZE_X) {
        for (int y = -limit+offset; y<limit+offset; y += BLOCK_SIZE_Y) {
            for (int z = -limit; z<limit; z += BLOCK_SIZE_Z) {
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

static Sector* getSector(const vec3i tilePos, SectorXYMap sectors)
{
    vec3i sectorPos = GetSectorNumber(tilePos);
    vec2i xyPos(sectorPos.X, sectorPos.Y);
    auto xy = sectors.find(xyPos);

    if (xy == sectors.end()) { return 0; }

    SectorZMap *zMap = xy->second;
    auto z = zMap->find(sectorPos.Z);

    if (z == zMap->end()) { return 0; }

    return z->second;
}


Tile World::getTile(const vec3i tilePos)
{
    auto sector = getSector(tilePos, m_sectors);
    if (sector) {
        auto lookedUp = sector->getTile(tilePos);

        if (!GetFlag(lookedUp.flags, TILE_INVALID)) { return lookedUp; }
    }

    /* May fail, but if it works we're all good */
    auto fromDisk = loadTileFromDisk(tilePos);
    if (!GetFlag(fromDisk.flags, TILE_INVALID)) { return fromDisk; }

    //Invalid tile! loading was not successfull! :):):):)
    if (m_pGame->isServer()) {
        generateBlock(tilePos);
        return (sector ? sector : getSector(tilePos, m_sectors))->getTile(tilePos);
    } else {
        /* Send request to sever!! */
        printf("Implement etc\n");
        BREAKPOINT;
    }
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

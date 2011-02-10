#include "World.h"
#include "Game.h"
#include "Util.h"
#include "Renderer.h"

World::World(IVideoDriver *driver)
    : m_isServer(true)
{
    m_pRenderer = new Renderer(this, driver);

//*
    const s32 limit = 32;//BLOCK_SIZE_X*CHUNK_SIZE_X*SECTOR_SIZE_X;
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

Sector* World::allocateSector(vec3i sectorPos)
{
    auto sector = new Sector;
    m_sectors[sectorPos] = sector;
    
    return sector;
}


Sector* World::getSector(const vec3i tilePos, bool get)
{
    vec3i sectorPos = GetSectorNumber(tilePos);
    auto found = m_sectors.find(sectorPos);
    
    return found == m_sectors.end()
        ? (get ? allocateSector(sectorPos) : 0)
        : found->second;
}

void World::generateBlock(const vec3i &tilePos)
{
    auto pSector = getSector(tilePos, true);

    pSector->generateBlock(tilePos, &m_worldGen);

    /* DO OPTIMIZATION LIKE CHECKING IF ALL THINGS ARE AIR ETC */

    /* Store to harddrive? schedule it? */
}

//const SectorList& World::getAllSectors()
//{
//    return m_sectorList;
//}

void World::addUnit(Unit* u)
{
    m_unitCount += 1;
    getSector(u->pos, true)->addUnit(u);

    RangeFromTo range(
        u->pos.X-2, u->pos.X + 3,
        u->pos.Y-2, u->pos.Y + 3,
        u->pos.Z-2, u->pos.Z + 3);
    foreach (posit, range) {
        auto pos = *posit;
        getSector(pos)->incCount();
    }
}

void World::render()
{
    m_pRenderer->preRender();

    foreach (sect, m_sectors) {
        /* Culling based on sectors */
        Sector *pSector = sect->second;
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


Tile World::getTile(const vec3i tilePos, bool loadFromDisk, bool create)
{
    auto sector = getSector(tilePos, loadFromDisk || create);
    
    if (!sector) { return INVALID_TILE(); }

    auto lookedUp = sector->getTile(tilePos);
    if (!GetFlag(lookedUp.flags, TILE_INVALID)) { return lookedUp; }

    if (!loadFromDisk) { return INVALID_TILE(); }

    auto fromDisk = loadTileFromDisk(tilePos);
    if (!GetFlag(fromDisk.flags, TILE_INVALID)) { return fromDisk; }
  
    if (!create) { return INVALID_TILE(); }

    if (m_isServer) {
        generateBlock(tilePos);
        return sector->getTile(tilePos);
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

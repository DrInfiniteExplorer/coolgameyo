#include "World.h"
#include "Game.h"
#include "Util.h"
#include "Renderer.h"

World::World()
    : m_isServer(true), m_unitCount(0)
{

    vec2i xy(8,8);
    auto u = new Unit;
    u->pos = getTopTilePos(xy);
    u->pos.Z += 1;
    addUnit(u);
    floodFillVisibility(xy);

}


World::~World(void)
{
}

Tile World::loadTileFromDisk(const vec3i &tilePos)
{
    return INVALID_TILE();
}

SectorXY World::getSectorXY(vec2i xy)
{
    SectorXY ret;
    ret.heightmap = (SectorXY::Heightmap*)malloc(sizeof *ret.heightmap);

    // look at disk for xy ???
    
    RangeFromTo range(0,128,0,128,0,1);
    foreach (it, range) {
        auto v = *it;
        (*ret.heightmap)[v.X][v.Y] = m_worldGen.maxZ(vec2i(v.X,v.Y));
    }
    return ret;
}

Sector* World::allocateSector(vec3i sectorPos)
{
    vec2i xy(sectorPos.X, sectorPos.Y);
    auto it = m_sectorXY.find(xy);

    if (it == m_sectorXY.end()) {
        it = m_sectorXY.insert(std::make_pair(xy, getSectorXY(xy))).first;
    }
    
    auto z = sectorPos.Z;

    auto sector = new Sector;

    auto ins2 = it->second.sectors.insert(std::make_pair(z, sector));
    assert (ins2.second);

    m_sectorList.push_back(sector);

    return sector;
}


Sector* World::getSector(const vec3i tilePos, bool get)
{
    vec3i sectorPos = GetSectorNumber(tilePos);
    vec2i xy(sectorPos.X, sectorPos.Y);
    auto found = m_sectorXY.find(xy);

    if (found != m_sectorXY.end()) {
        auto foundz = found->second.sectors.find(sectorPos.Z);
        if (foundz != found->second.sectors.end()) {
            return foundz->second;
        }
    }
        
    return get ? allocateSector(sectorPos) : 0;
}


Block World::getBlock(const vec3i tilePos, bool getSector, bool get)
{
    auto s = this->getSector(tilePos, getSector);
    if (!s){
        //BREAKPOINT;
        return INVALID_BLOCK();
    }

    auto b = s->getBlock(tilePos);
    if (!b.isValid() && get) {
        generateBlock(tilePos);
        b = s->getBlock(tilePos);
    }
    assert (b.isValid());
    return b;
}

void World::setBlock(const vec3i tilePos, Block newBlock)
{
    getBlock(tilePos, true);
    getSector(tilePos)->setBlock(tilePos, newBlock);
}

void World::generateBlock(const vec3i &tilePos)
{
    auto pSector = getSector(tilePos, true);

    pSector->generateBlock(tilePos, &m_worldGen);

    /* DO OPTIMIZATION LIKE CHECKING IF ALL THINGS ARE AIR ETC */

    /* Store to harddrive? schedule it? */
}



std::vector<Sector*> *World::lock()
{
    // Implement thread thingies.
    return &m_sectorList;
}

void World::unlock(std::vector<Sector*> *data)
{
    assert(data == &m_sectorList);
}




void World::addUnit(Unit* u)
{
    m_unitCount += 1;
    getSector(u->pos)->addUnit(u);

    //RangeFromTo range(-2, 3, -2, 3, -2, 3);
//    RangeFromTo range(0, 2, 0, 2, 0, 2);
    RangeFromTo range(0, 2, 0, 1, 0, 1);
    foreach (posit, range) {
        auto pos = u->pos;
        pos.X += TILES_PER_SECTOR_X * (*posit).X;
        pos.Y += TILES_PER_SECTOR_Y * (*posit).Y;
        pos.Z += TILES_PER_SECTOR_Z * (*posit).Z;
        getSector(pos)->incCount();
    }

}


Tile World::getTile(const vec3i tilePos, bool fetch, bool createBlock, bool createSector)
{
    auto sector = getSector(tilePos, createSector);
    
    if (!sector) { return INVALID_TILE(); }

    auto lookedUp = sector->getTile(tilePos);
    if (lookedUp.isValid()) { return lookedUp; }

    if (!fetch) { return INVALID_TILE(); }

    auto fromDisk = loadTileFromDisk(tilePos);
    if (fromDisk.isValid()) { return fromDisk; }
    
    if (!createBlock) { return INVALID_TILE(); }
    
    if (m_isServer) {
        generateBlock(tilePos);
        ASSERT(sector->getTile(tilePos).isValid());
        return sector->getTile(tilePos);
    } else {
        /* Send request to sever!! */
        BREAKPOINT;
        printf("Implement etc\n");
    }

    BREAKPOINT;
}

vec3i World::getTopTilePos(const vec2i xy)
{
    auto x = xy.X;
    auto y = xy.Y; 
    auto z = m_worldGen.maxZ(xy);
    while (m_worldGen.getTile(vec3i(x, y, z)).type == ETT_AIR) {
        z -= 1;
    }
    return vec3i(x,y,z);
}


void World::floodFillVisibility(const vec2i xypos)
{

    // Z is now the air above highest ground level at xypos
    auto startPos = getTopTilePos(xypos);
    
    startPos.Z += 1;
    
    std::set<vec3i> work;
    work.insert(GetBlockWorldPosition(startPos));
    
    while (!work.empty()) {
        auto pos = *work.begin();
        work.erase(pos);
        
        auto block = getBlock(pos, false, true);
        if (!block.isValid() || block.isSeen()) {
            if (!block.isValid()) {
                //printf("Block not valid: %d %d %d", pos.X, pos.Y, pos.Z);
            }
            continue;
        }
        block.setSeen();
        if (block.isSparse()) {
            if (block.type == ETT_AIR) {
                work.insert(pos + vec3i(TILES_PER_BLOCK_X, 0, 0));
                work.insert(pos - vec3i(TILES_PER_BLOCK_X, 0, 0));
                work.insert(pos + vec3i(0, TILES_PER_BLOCK_Y, 0));
                work.insert(pos - vec3i(0, TILES_PER_BLOCK_Y, 0));
                work.insert(pos + vec3i(0, 0, TILES_PER_BLOCK_Z));
                work.insert(pos - vec3i(0, 0, TILES_PER_BLOCK_Z));
            } else {
                BREAKPOINT;
            }
        } else {
            // map through all the tiles in the block; if any edge is air,
            // add that edge block to work

            // this will be shitty

            RangeFromTo range(0, TILES_PER_BLOCK_X,
                    0, TILES_PER_BLOCK_Y,
                    0, TILES_PER_BLOCK_Z);
            foreach (it, range) {
                auto rel = *it;
                //printf("% ...> tile %5d%5d%5d\n", rel.X,rel.Y,rel.Z);
                auto tp = rel + pos;
                Tile t = block.getTile(tp);
                if (t.type == ETT_AIR) {
                    t.setSeen();
                    if (rel.X == 0) {
                        work.insert(pos - vec3i(TILES_PER_BLOCK_X, 0, 0));
                    } else if (rel.X == TILES_PER_BLOCK_X - 1) {
                        work.insert(pos + vec3i(TILES_PER_BLOCK_X, 0, 0));
                    }
                    if (rel.Y == 0) {
                        work.insert(pos - vec3i(0, TILES_PER_BLOCK_Y, 0));
                    } else if (rel.Y == TILES_PER_BLOCK_Y - 1) {
                        work.insert(pos + vec3i(0, TILES_PER_BLOCK_Y, 0));
                    }
                    if (rel.Z == 0) {
                        work.insert(pos - vec3i(0, 0, TILES_PER_BLOCK_Z));
                    } else if (rel.Z == TILES_PER_BLOCK_Z - 1) {
                        work.insert(pos + vec3i(0, 0, TILES_PER_BLOCK_Z));
                    }
                } else {
                    Tile neighbor;
                    neighbor = getTile(vec3i(tp.X-1, tp.Y, tp.Z));
                    if (!neighbor.isValid() || neighbor.type == ETT_AIR) {
                        t.setSeen();
                        goto END_LOL;
                    }
                    neighbor = getTile(vec3i(tp.X+1, tp.Y, tp.Z));
                    if (!neighbor.isValid() || neighbor.type == ETT_AIR) {
                        t.setSeen();
                        goto END_LOL;
                    }
                    neighbor = getTile(vec3i(tp.X, tp.Y-1, tp.Z));
                    if (!neighbor.isValid() || neighbor.type == ETT_AIR) {
                        t.setSeen();
                        goto END_LOL;
                    }
                    neighbor = getTile(vec3i(tp.X, tp.Y+1, tp.Z));
                    if (!neighbor.isValid() || neighbor.type == ETT_AIR) {
                        t.setSeen();
                        goto END_LOL;
                    }
                    neighbor = getTile(vec3i(tp.X, tp.Y, tp.Z-1));
                    if (!neighbor.isValid() || neighbor.type == ETT_AIR) {
                        t.setSeen();
                        goto END_LOL;
                    }
                    neighbor = getTile(vec3i(tp.X, tp.Y, tp.Z+1));
                    if (!neighbor.isValid() || neighbor.type == ETT_AIR) {
                        t.setSeen();
                        goto END_LOL;
                    }
                END_LOL:;
                }
                block.setTile(tp, t);
            }
        }
        setBlock(pos, block);
    }
}

void World::setTile(vec3i tilePos, const Tile newTile)
{
    getSector(tilePos, true)->setTile(tilePos, newTile);
    notifyTileChange(tilePos);
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

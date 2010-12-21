#include "World.h"
#include "Game.h"

World::World(Game *pGame)
   : m_pGame(pGame)
{
}


World::~World(void)
{
}

Tile World::loadTileFromDisk(const vec3i &tilePos){

    return INVALID_TILE();
}

Tile World::getTile(const vec3i &tilePos)
{
   /* Speed things up by keeping a cache of the last x indexed sectors? */

    Tile returnTile;
    
    vec2i xyPos(tilePos.X, tilePos.Y);
    auto iter = m_sectors.find(xyPos);
    if(m_sectors.end() != iter){
        SectorZMap *zMap = iter->second; // (*iter)->second
        auto iter2 = zMap->find(tilePos.Z);
        if(zMap->end() != iter2){
            Sector *pSector = iter2->second;
            returnTile = pSector->getTile(tilePos);
            //Implement the rest?
            BREAKPOINT;
            return returnTile;
        }
    }

    /* May fail, but if it works we're all good */
    returnTile = loadTileFromDisk(tilePos);
    if(GetFlag(returnTile.flags, TILE_INVALID)){
        //Invalid tile! loading was not successfull! :):):):)
        m_pGame->requestTileFromServer(tilePos);
    }

    return returnTile;
}

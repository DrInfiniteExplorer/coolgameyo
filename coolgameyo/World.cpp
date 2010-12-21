#include "World.h"


World::World(void)
{
}


World::~World(void)
{
}


void World::GetTile(const iVec3 tilePos, Tile &outTile){
    iVec2 xyPos(tilePos.X, tilePos.Y);
    auto iter = m_sectors.find(xyPos);
    if(m_sectors.end() != iter){
        SectorZMap *zMap = iter->second; // (*iter)->second
        auto iter2 = zMap->find(tilePos.Z);
        if(zMap->end() != iter2){
            Sector *pSector = iter2->second;
            pSector->GetTile(tilePos, outTile);
            //Implement the rest?
            BREAKPOINT;
            return;
        }
    }

    /* How to handle not having this tile when we need it? */
    /* Maybe by requesting it, and returning some exception or error code, */
    /*  and let the caller be suspended until we have the tile(somehow) */
    /* The suspension should work on all levels(sector[pos], chunk[pos]) */
    /* Things like rendering should not be suspended but like other stuff */
    /* may be, like where a dwarf walks or something */


    /* Get tile!!  */
    /* Is server? GENERATE/LOAD/ROAR! */
    /* Else ask server for data */
}

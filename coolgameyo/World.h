#pragma once

#include "include.h"
#include "Sector.h"
#include "WorldGenerator.h"


class World
{
private:
   /* sparse array med sectorer som är laddade? */


   /* Eventually put this into a sector-handling class? */
   typedef class std::map<u32, Sector*>         SectorZMap;
   typedef class std::map<iVec2, SectorZMap*>   SectorXYMap;

   SectorXYMap        m_sectors;

   /* Data som används som parametrar för att generera världen? */
   WorldGenerator     m_worldGen;

   bool               m_isServer;

   IVideoDriver      *m_pDriver;

public:
   World(IVideoDriver *pDriver);
   ~World(void);

   void render();

   /* Funktion för att generera världen? */
   void GetTile(const iVec3 tilePos, Tile &outTile);
   void SetTile(iVec3 tilePos, const Tile &newTile);
};


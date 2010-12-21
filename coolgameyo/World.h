#pragma once

#include "include.h"
#include "Sector.h"
#include "WorldGenerator.h"


class World
{
private:
   /* sparse array med sectorer som �r laddade? */


   /* Eventually put this into a sector-handling class? */
   typedef class std::map<u32, Sector*>         SectorZMap;
   typedef class std::map<iVec2, SectorZMap*>   SectorXYMap;

   SectorXYMap        m_sectors;

   /* Data som anv�nds som parametrar f�r att generera v�rlden? */
   WorldGenerator     m_worldGen;

   bool               m_isServer;

   IVideoDriver      *m_pDriver;

public:
   World(IVideoDriver *pDriver);
   ~World(void);

   void render();

   /* Funktion f�r att generera v�rlden? */
   void GetTile(const iVec3 tilePos, Tile &outTile);
   void SetTile(iVec3 tilePos, const Tile &newTile);
};


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
   typedef class std::map<vec2i, SectorZMap*>   SectorXYMap;

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
   void getTile(const vec3i tilePos, Tile &outTile);
   void setTile(vec3i tilePos, const Tile &newTile);
};


#pragma once

#include "include.h"
#include "Sector.h"
#include "WorldGenerator.h"

class Game;

class World
{
private:
   /* sparse array med sectorer som är laddade? */


   /* Eventually put this into a sector-handling class? */
   typedef class std::map<u32, Sector*>         SectorZMap;
   typedef class std::map<vec2i, SectorZMap*>   SectorXYMap;

   SectorXYMap       m_sectors;

   /* Data som används som parametrar för att generera världen? */
   WorldGenerator    m_worldGen;
   Game             *m_pGame;

   Tile loadTileFromDisk(const vec3i &tilePos);

public:
   World(Game* pGame);
   ~World(void);

   void render();

   /* Funktion för att generera världen? */
   Tile getTile(const vec3i &tilePos);
   void setTile(vec3i tilePos, const Tile &newTile);
};


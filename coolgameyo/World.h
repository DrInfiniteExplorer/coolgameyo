#pragma once

#include "include.h"
#include "Sector.h"
#include "WorldGenerator.h"

class Game;

class World
{
private:
   /* sparse array med sectorer som är laddade? */

   SectorXYMap       m_sectors;
   SectorList        m_sectorList;

   /* Data som används som parametrar för att generera världen? */
   WorldGenerator    m_worldGen;
   Game             *m_pGame;
   IVideoDriver     *m_pDriver;

   Tile loadTileFromDisk(const vec3i &tilePos);

   void generateBlock(const vec3i &tilePos);

   const SectorList& getAllSectors();

public:
   World(Game* pGame);
   ~World(void);

   void render();

   /* Funktion för att generera världen? */
   Tile getTile(const vec3i &tilePos);
   void setTile(vec3i tilePos, const Tile &newTile);
};


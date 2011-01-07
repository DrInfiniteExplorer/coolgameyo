#pragma once

#include "include.h"
#include "Sector.h"
#include "WorldGenerator.h"
#include "WorldListener.h"

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

   std::set<WorldListener*> m_listeners;

   void notifySectorLoad(vec3i sectorPos);
   void notifySectorUnload(vec3i sectorPos);
   void notifyTileChange(vec3i tilePos);

   Tile loadTileFromDisk(const vec3i &tilePos);

   void generateBlock(const vec3i &tilePos);

   const SectorList& getAllSectors();

public:
   World(Game* pGame);
   ~World(void);

   void render();

   /* Funktion för att generera världen? */
   Tile getTile(const vec3i tilePos);
   void setTile(vec3i tilePos, const Tile &newTile);

   void addListener(WorldListener* listener) {
       m_listeners.insert(listener);
   }
   void removeListener(WorldListener* listener) {
       m_listeners.erase(listener);
   }
};


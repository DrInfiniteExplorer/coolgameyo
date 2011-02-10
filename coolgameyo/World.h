#pragma once

#include "include.h"
#include "Sector.h"
#include "WorldGenerator.h"
#include "WorldListener.h"

class Game;
class Renderer;

class World
{
private:
   /* sparse array med sectorer som är laddade? */

   std::map<vec3i, Sector*>  m_sectors;
   //SectorList                m_sectorList;

   /* Data som används som parametrar för att generera världen? */
   WorldGenerator            m_worldGen;
   bool                      m_isServer; // TODO: FIX
   //IVideoDriver     *m_pDriver;
   Renderer                 *m_pRenderer;

   int                       m_unitCount;

   std::unordered_set<WorldListener*> m_listeners;

   void notifySectorLoad(vec3i sectorPos);
   void notifySectorUnload(vec3i sectorPos);
   void notifyTileChange(vec3i tilePos);

   Tile loadTileFromDisk(const vec3i &tilePos);

   void generateBlock(const vec3i &tilePos);

   //const SectorList& getAllSectors();

   Sector* allocateSector(vec3i sectorPos);
   Sector* getSector(const vec3i sectorPos, bool get=true);

public:
   World(IVideoDriver* driver);
   ~World(void);

   void render();

   void addUnit(Unit* unit);

   Tile getTile(const vec3i tilePos, bool pageIn=true, bool create=true);

   void setTile(vec3i tilePos, const Tile &newTile);

   void addListener(WorldListener* listener)
   {
       m_listeners.insert(listener);
   }
   void removeListener(WorldListener* listener)
   {
       m_listeners.erase(listener);
   }
};


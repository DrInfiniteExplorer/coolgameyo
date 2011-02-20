#pragma once

#include "include.h"
#include "Sector.h"
#include "WorldGenerator.h"
#include "WorldListener.h"

class Game;
class Renderer;

struct SectorXY;

class World
{
private:
   std::map<vec2i, SectorXY>  m_sectorXY;
   std::vector<Sector*>       m_sectorList;

   WorldGenerator            m_worldGen;
   bool                      m_isServer; // TODO: FIX


   /* Data som används som parametrar för att generera världen? */
/*
   WorldGenerator    m_worldGen;
   Game             *m_pGame;
*///Was removed luben unsure etc remove if not breaks lolololololol   
   int                       m_unitCount;

   std::unordered_set<WorldListener*> m_listeners;

   void notifySectorLoad(vec3i sectorPos);
   void notifySectorUnload(vec3i sectorPos);
   void notifyTileChange(vec3i tilePos);

   Tile loadTileFromDisk(const vec3i &tilePos);

   void generateBlock(const vec3i &tilePos);

   SectorXY getSectorXY(vec2i xy);
   Sector* allocateSector(vec3i sectorPos);
   Sector* getSector(const vec3i sectorPos, bool get=true);
   Block getBlock(const vec3i tilePos, bool generate=true, bool getSector=false);
   void setBlock(const vec3i tilePos, Block newBlock);

public:
   World();
   ~World(void);

   std::vector<Sector*> *lock();
   void unlock(std::vector<Sector*> *data);

   void addUnit(Unit* unit);

   Tile getTile(const vec3i tilePos, bool fetch=true, bool createBlock=true, bool createSector=false);

   vec3i getTopTilePos(const vec2i xy);

   void setTile(vec3i tilePos, const Tile newTile);

   void floodFillVisibility(const vec2i xypos);

   void addListener(WorldListener* listener) { m_listeners.insert(listener); }
   void removeListener(WorldListener* listener) { m_listeners.erase(listener); }
};


struct SectorXY {
    typedef int Heightmap[TILES_PER_SECTOR_X][TILES_PER_SECTOR_Y];

    std::map<s32, Sector*> sectors;
    Heightmap* heightmap;
};


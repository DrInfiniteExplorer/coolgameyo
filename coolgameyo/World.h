#pragma once

#include "Sector.h"
#include "WorldGenerator.h"


class World
{
public:
   World(void);
   ~World(void);

   void render();

private:
   /* sparse array med sectorer som är laddade? */

   /* Funktion för att generera världen? */

   /* Data som används som parametrar för att generera världen? */
   WorldGenerator    m_worldGen;
};


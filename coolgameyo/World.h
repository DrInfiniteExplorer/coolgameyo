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
   /* sparse array med sectorer som �r laddade? */

   /* Funktion f�r att generera v�rlden? */

   /* Data som anv�nds som parametrar f�r att generera v�rlden? */
   WorldGenerator    m_worldGen;
};


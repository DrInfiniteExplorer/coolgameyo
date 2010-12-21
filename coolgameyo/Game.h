#pragma once

#include "include.h"
#include "World.h"

class Game
{
private:
   IrrlichtDevice *m_pDevice;
   World           m_world;
public:
   Game(IrrlichtDevice *pDevice);
   ~Game(void);


};


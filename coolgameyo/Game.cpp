#include "Game.h"


Game::Game(IrrlichtDevice *pDevice)
   : m_world(pDevice->getVideoDriver()),
   m_pDevice(pDevice)
{
}


Game::~Game(void)
{
}

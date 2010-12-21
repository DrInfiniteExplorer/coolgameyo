#include "Game.h"


Game::Game(IrrlichtDevice *pDevice, bool isServer, bool isWorker)
   : m_pDevice(pDevice),
   m_isServer(isServer),
   m_isWorker(isWorker)
{
    m_pWorld = new World(this);
}


Game::~Game(void)
{
    delete m_pWorld;
}


void Game::requestTileFromServer(const vec3i &tilePosition){
    if(m_isServer){

    }else{
        printf("Tell the server to feed me with a sector!!!\n");
        BREAKPOINT;
    }
}

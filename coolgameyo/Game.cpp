#include "Game.h"


Game::Game(IrrlichtDevice *pDevice, bool isServer, bool isWorker)
   : m_pDevice(pDevice),
   m_isServer(isServer),
   m_isWorker(isWorker)
{
    m_pWorld = new World(this);

    pDevice->getSceneManager()->addCameraSceneNodeFPS();
}


Game::~Game(void)
{
    delete m_pWorld;
}


void Game::run(){
    while (m_pDevice->run()) {
        m_pDevice->getVideoDriver()->beginScene(true, true, SColor(255, 128, 0, 0));

        /* Call world->Render etc */
        /* Actually might already be in world->run() or something */
        m_pDevice->getSceneManager()->drawAll(); //Is only camera.
        m_pWorld->render();

        m_pDevice->getVideoDriver()->endScene();
    }
}


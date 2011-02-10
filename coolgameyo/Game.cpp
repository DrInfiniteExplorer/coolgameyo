#include "Game.h"


Game::Game(IrrlichtDevice *pDevice, World* world, bool isServer, bool isWorker)
   : m_pDevice(pDevice),
   m_isServer(isServer),
   m_isWorker(isWorker),
   m_pWorld(world)
{
}


Game::~Game(void)
{
    delete m_pWorld;
}


void Game::run(){

    ICameraSceneNode *pCam = m_pDevice->getSceneManager()->addCameraSceneNodeFPS(0, 100, 0.05f);
//    pCam->setUpVector(vec3f(0, 0, 1));
    pCam->setPosition(vec3f(96, 0, 0));
    pCam->setTarget(vec3f(0, 0, 0));

    SMaterial mat;
    mat.Lighting = false;

    //m_pDevice->getSceneManager()->addCubeSceneNode(1);
    ITimer *pTimer = m_pDevice->getTimer();
    u32 last = pTimer->getRealTime();
    IVideoDriver *pDriver = m_pDevice->getVideoDriver();
    const int CNT=5;
    u32 times[CNT];
    while (m_pDevice->run()) {
        u32 now = pTimer->getRealTime();
        u32 delta = now-last;
        last = now;

        u32 sum = 0;
        for(int i=0;i<CNT-1;i++){
            sum+= times[i]=times[i+1];
        }
        sum+= times[CNT-1] = delta;
        float fps = (CNT*1000.0f) / float(sum);
        wchar_t arr[80];
        swprintf_s(arr, L"FPS %5.2f over %d frames", fps, CNT);
        m_pDevice->setWindowCaption(arr);

        pDriver->beginScene(true, true, SColor(255, 128, 0, 0));

        /* Call world->Render etc */
        /* Actually might already be in world->run() or something */
        m_pDevice->getSceneManager()->drawAll(); //Is only camera.
        m_pDevice->getVideoDriver()->setMaterial(mat);

        m_pWorld->render();

        pDriver->endScene();
    }
}


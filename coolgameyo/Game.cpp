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


void Game::run(){

    ICameraSceneNode *pCam = m_pDevice->getSceneManager()->addCameraSceneNodeFPS(0, 100, 0.05f);
//    pCam->setUpVector(vec3f(0, 0, 1));
    pCam->setPosition(vec3f(32, 0, 32));
    pCam->setTarget(vec3f(0, 0, 0));

    m_pDevice->getSceneManager()->addCubeSceneNode(1);

    IVideoDriver *pDriver = m_pDevice->getVideoDriver();
    while (m_pDevice->run()) {
        pDriver->beginScene(true, true, SColor(255, 128, 0, 0));

        /* Call world->Render etc */
        /* Actually might already be in world->run() or something */
        m_pDevice->getSceneManager()->drawAll(); //Is only camera.

        m_pWorld->render();

/*        SMaterial mat;
        //mat.Lighting = false;
        pDriver->setMaterial(mat);
        aabbox3df box(-0.5f, -0.5f, -0.5f, 0.5f, 0.5f, 0.5f);
        {
        matrix4 mat;
        mat.setTranslation(vec3f(1, 0, 0));
        pDriver->setTransform(ETS_WORLD, mat); 
        pDriver->draw3DBox(box);
        }
*/
        /*
            SMaterial mat;
            mat.Lighting = false;
            //pDriver->setMaterial(mat);
            matrix4 matr;
            matr = pDriver->getTransform(ETS_WORLD);
            vec3f blockPos = matr.getTranslation();
            vec3f pos;
            for(int x=-32;x<32;x++){
                pos.X = blockPos.X + x;
            for(int y=-32;y<32;y++){
                pos.Y = blockPos.Y + y;
            for(int z=-32;z<32;z++){
                pos.Z = blockPos.Z + z;
                matr.setTranslation(pos);
                pDriver->setTransform(ETS_WORLD, matr);
                pDriver->draw3DBox(box);
            }
            }
            }
*/

        pDriver->endScene();
    }
}


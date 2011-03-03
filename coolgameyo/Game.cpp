#include "Game.h"
#include "Renderer.h"
#include "Camera.h"

Game::Game(bool isClient, bool isServer, bool isWorker)
   : m_isServer(isServer),
   m_isWorker(isWorker),
   m_isClient(isClient)
{
    memset(m_keyMap, 0, sizeof(m_keyMap));


    m_pWorld = new World();


    if(m_isClient){
        
        SIrrlichtCreationParameters sex;
        sex.DriverType = EDT_OPENGL;
        sex.Bits = 32;
        sex.ZBufferBits = 16; //Or 32? Make settingable?
        sex.Fullscreen = false;
        sex.Vsync = false;
        sex.AntiAlias = sex.Fullscreen ? 8 : 0; //this is FSAA
        sex.HighPrecisionFPU = false; //test false also.
        sex.EventReceiver = this;
        sex.UsePerformanceTimer = true;
        m_pDevice = createDeviceEx(sex);
        m_sched = new Scheduler(m_pWorld, m_pDevice->getTimer());
        m_pRenderer = new Renderer(m_pWorld, m_pDevice->getVideoDriver());
        m_pCamera = new Camera();
    } else {
        assert (0);
    }


}


Game::~Game(void)
{
    delete m_pCamera;

    if(m_pRenderer){
        delete m_pRenderer;
    }
    if(m_pDevice){
        m_pDevice->drop();
    }

    delete m_pWorld;
}

bool Game::onKey(const SEvent &ev){
    const SEvent::SKeyInput &key = ev.KeyInput;
    m_keyMap[key.Key] = key.PressedDown;
    return false;
}

bool Game::onMouse(const SEvent &ev){
    const SEvent::SMouseInput &mouse = ev.MouseInput;

    /*  BLAHBLAH MANY IFFSES  */
    if(mouse.Event == EMIE_MOUSE_MOVED){
        dimension2d<u32> wndDim = m_pDevice->getVideoDriver()->getScreenSize();
        s32 ScreenCenterX = wndDim.Width / 2;
        s32 ScreenCenterY = wndDim.Height/ 2;   // <-- luben's settings. yä.
        s32 dx, dy;
        dx = mouse.X - ScreenCenterX;
        dy = mouse.Y - ScreenCenterY;
        if(dx!=0 || dy!=0){
            m_pDevice->getCursorControl()->setPosition(ScreenCenterX, ScreenCenterY);
            m_pCamera->mouseMove( dx,  dy);
        }
    }

    return false;
}

bool Game::OnEvent(const SEvent &irrlichtEvent){
    if(irrlichtEvent.EventType == EET_MOUSE_INPUT_EVENT){
        return onMouse(irrlichtEvent);
    }else if(irrlichtEvent.EventType == EET_KEY_INPUT_EVENT){
        return onKey(irrlichtEvent);
    }
    return false;
}


void Game::run(){
/*
    ICameraSceneNode *pCam = m_pDevice->getSceneManager()->addCameraSceneNodeFPS(0, 100, 0.05f);
    pCam->setPosition(vec3f(96, 0, 0));
    pCam->setTarget(vec3f(0, 0, 0));
*/

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

        if(m_keyMap[KEY_KEY_W]){
            m_pCamera->axisMove( 0.1f,  0.0f,  0.0f);
        }
        if(m_keyMap[KEY_KEY_S]){
            m_pCamera->axisMove(-0.1f,  0.0f,  0.0f);
        }
        if(m_keyMap[KEY_KEY_A]){
            m_pCamera->axisMove( 0.0f, -0.1f,  0.0f);
        }
        if(m_keyMap[KEY_KEY_D]){
            m_pCamera->axisMove( 0.0f,  0.1f,  0.0f);
        }
        if(m_keyMap[KEY_SPACE]){
            m_pCamera->axisMove( 0.0f,  0.0f,  0.1f);
        }
        if(m_keyMap[KEY_LCONTROL]){
            m_pCamera->axisMove( 0.0f,  0.0f, -0.1f);
        }

        pDriver->beginScene(true, true, SColor(255, 128, 0, 0));
        //m_pDevice->getSceneManager()->drawAll(); //Is only camera. <--Not even that anymore, MOAOAAOA!

        m_pRenderer->preRender(m_pCamera);
        m_pRenderer->renderWorld();
        m_pRenderer->postRender();
        m_pRenderer->renderBlobs();


        pDriver->endScene();
    }
}


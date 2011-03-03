#pragma once

#include "include.h"
#include "World.h"
#include "Scheduler.h"

class Camera;

class Game : public IEventReceiver
{
private:
    IrrlichtDevice   *m_pDevice;
    World            *m_pWorld;

    Camera           *m_pCamera;
    Renderer         *m_pRenderer;

    Scheduler        *m_sched;

    bool              m_isClient;
    bool              m_isServer;        //WE ARE A SERWOR!
    bool              m_isWorker;    //We help the servoar with retardation of dudes and such things.

    bool              m_keyMap[256];

    bool onMouse(const SEvent &mouseEvent);
    bool onKey(const SEvent &keyEvent);
    virtual bool OnEvent(const SEvent& event); /*  Inherited from IEventReceiver, redirects to onMouse and onKey.  */
public:
   Game(bool isClient, bool isServer, bool isWorker); //isServer and isWorker are mutually exclusive.
   ~Game(void);

   IrrlichtDevice *getDevice() const
   {
       return m_pDevice;
   };

   void run();

   bool isServer() const
   {
       return m_isServer;
   }
};


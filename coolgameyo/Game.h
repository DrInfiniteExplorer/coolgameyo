#pragma once

#include "include.h"
#include "World.h"

class Game
{
private:
   IrrlichtDevice   *m_pDevice;
   World            *m_pWorld;
   bool              m_isServer;        //WE ARE A SERWOR!
   bool              m_isWorker;    //We help the servoar with retardation of dudes and such things.
public:
   Game(IrrlichtDevice *pDevice, bool isServer, bool isWorker); //isServer and isWorker are mutually exclusive.
   ~Game(void);

   IrrlichtDevice *getDevice() const{
       return m_pDevice;
   };

   void run();

   bool isServer() const{
       return m_isServer;
   }
};


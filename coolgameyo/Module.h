#pragma once

#include "include.h"
#include "Sector.h"
#include "World.h"

class Module : public WorldListener
{
protected:
    World* world;
    Module(World* w) : world(w) { }
public:
    virtual void tick() = 0;
};

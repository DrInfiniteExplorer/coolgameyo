#pragma once

#include "include.h"
//#include "World.h" // WTF!!!

class World;

class AI; // NOT IMPLEMENTED D::!!!

struct Unit
{
    bool active;
    bool alive;
    float hitpoints;

    vec3i pos;

    AI* ai;

    int tick(World* world);
};


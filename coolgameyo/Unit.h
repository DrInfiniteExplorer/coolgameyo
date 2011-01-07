#pragma once

#include "include.h"
#include "World.h"

class AI; // NOT IMPLEMENTED D::!!!

class Unit
{
public:
    // is this sane?
    vec3i pos;
    vec3f offset;

    AI* ai;

    virtual int tick(World* world);
};

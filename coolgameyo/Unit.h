#pragma once

#include "include.h"

class AI;

class Unit
{
public:
    // is this sane?
    vec3i pos;
    vec3f offset;

    AI* ai;

    virtual int tick();
};

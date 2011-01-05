#pragma once

#include "include.h"
#include "Sector.h"
#include "WorldListener.h"

class Module : WorldListener
{
    virtual void tick() = 0;
};

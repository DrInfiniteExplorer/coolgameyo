#pragma once

#include "include.h"

#include "Module.h"
#include "Sector.h"

#include "Unit.h"


/*
 * This module does not own the units, the world should keep ownership.
 * What it does, however, is managing the ticking of units.
 *
 * Perhaps should be able to handle arbitrary game objects, such as pumps etc,
 * as well? I don't know.
 *
 */

class UnitModule : Module
{
    struct U
    {
        int delay;
        Unit* unit;

        U(int delay, Unit* u) : delay(delay), unit(u) { }
    };

    // Quad tree? Octree? per sector? :/
    // a std::vector per sector for now. D:
    //
    // index with GetSectorPosition(unit->pos)
    std::map<vec3i, std::vector<U> > units;

public:
    void tick();

    void notifySectorLoad(vec3i sectorPos);
    void notifySectorUnoad(vec3i sectorPos);

    void addUnit(Unit* unit);
};


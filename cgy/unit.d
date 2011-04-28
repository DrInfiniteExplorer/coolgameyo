
module unit;

import std.conv;

import modules;
import util;
import pos;

final class UnitType {
    string name;
    int x;
}

struct Unit {
    UnitType type;

    UnitPos pos;
    vec3d destination;
    int ticksUntilArrived;

    bool panics;

    vec3d movementPerTick() const @property {
        if(ticksUntilArrived < 1) { return vec3d(0.0, 0.0, 0.0); }
        return (destination - pos.value) / to!double(ticksUntilArrived);
    }

    void tick(int ticksLeft, PathModule blerp) {
        if (ticksLeft > 0) { // Was interrupted!!!!!!!
            assert (0);
        } else if (ticksLeft < 0) { // Back from some movement or shit
            assert (1 == 3);
        }


        assert (false);
    }
}


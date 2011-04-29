
module unit;

import std.conv;
import std.math;

import modules;
import util;
import pos;
import world;

final class UnitType {
    string name;
    int x;
}

struct Unit {
    UnitAI ai;
    UnitType type;
    UnitPos pos;
    vec3d destination;
    vec3d velocity;
    uint ticksToArrive;
    bool panics;



    //This function serve any purpose?
    void tick(int ticksLeft, PathModule blerp) {
        if (ticksLeft > 0) { // Was interrupted!!!!!!!
            assert (0);
        } else if (ticksLeft < 0) { // Back from some movement or shit
            assert (1 == 3);
        }


        assert (false);
    }
}

class UnitMovementChange : CHANGE {
    Unit* unit;
    //Will arrive at destination in frames frames (1 frame -> arrived by next frame)
    vec3d destination;
    uint ticksToArrive;
    this(Unit *u, vec3d dest, uint ticks){
        unit = u;
        destination = dest;
        ticksToArrive = ticks;
    }

    void apply(World world) {
        world.moveUnit(unit, destination, ticksToArrive);
    }
}

abstract class UnitAI {
    void tick(Unit *unit, ref CHANGE[] changes);
}

class MoveToAI : UnitAI {
    Unit *target;
    float speed;
    void delegate(Unit*) done;
    bool removeOnArrive;
    this(Unit* targetUnit, float speed, void delegate(Unit*) done = null, bool removeOnArrive=true){
        target = targetUnit;
        this.speed = speed;
        this.done = done;
        this.removeOnArrive = removeOnArrive;
    }

    void tick(Unit *unit, ref CHANGE[] changes) {
        if(unit.destination != target.pos.value){
            auto dist = (target.pos.value - unit.pos.value).getLength();
            int ticks = to!int(ceil(dist / speed));
            changes ~= new UnitMovementChange(unit, target.pos.value, ticks);
        }
        if(unit.pos == target.pos){
            if(done){
                done(unit);
            } else if(removeOnArrive){
                unit.ai = null;
            }
        }
    }
}


module unit;

import std.conv;
import std.exception;
import std.math;

import changelist;
import modules;
import pos;
import stolen.aabbox3d;
import util;
import world;

final class UnitType {
    string name;
    int x;
}

interface UnitAI {
    void tick(Unit* unit, ChangeList changeList);
}


struct Unit {

    const bool opEquals(ref const(Unit) u){
        enforce(0, "Implement Unit.opEquals or find where it's called and make not called!");
        asm {int 3;} //Apparently this needs to be implemented, or Unit.ai causes a lot of misery
        //No real understanding of this problem has been produced. You can try commenting this out
        //if you'd like. AFAIK we never ever want to compare units anyway though. Maybe we do. In
        //that case we'll have to implement this or fix the problem somehow.
        return type is u.type;
    }

    UnitAI ai;
    UnitType type;
    UnitPos pos;
    float rotation = 0; //radians

    vec3d destination;
    uint ticksToArrive;
    vec3d velocity;

    bool panics;

    float unitWidth = 1.f;
    float unitHeight = 2.f;
    float stepHeight = 0.5f;

    //Returns the bounding box of the unit, in world space.
    //If no parameter is passed, the units position is used as base,
    //otherwise the passed position is padded with the unit-size.
    aabbox3d!(double) aabb(const(vec3d)* v = null) const @property {
        if(v is null){
            v = &pos.value;
        }
        auto minPos = (*v)  - vec3d(unitWidth * 0.5, unitWidth*0.5, 0);
        auto maxPos = minPos + vec3d(unitWidth, unitWidth, unitHeight);
        return aabbox3d!double(minPos, maxPos);
    }

    //This function serve any purpose?
    void tick(int ticksLeft, PathModule blerp) {
        enforce(0, "This function is used");
        if (ticksLeft > 0) { // Was interrupted!!!!!!!
            assert (0);
        } else if (ticksLeft < 0) { // Back from some movement or shit
            assert (1 == 3);
        }

        enforce(0);
    }
}

class MoveToAI : UnitAI {

    Unit* target;
    float speed;
    void delegate(Unit*) done;
    bool removeOnArrive;
    this(Unit* targetUnit, float speed, void delegate(Unit*) done = null, bool removeOnArrive=true){
        target = targetUnit;
        this.speed = speed;
        this.done = done;
        this.removeOnArrive = removeOnArrive;
    }

    override void tick(Unit* unit, ChangeList changeList) {
        if (unit.destination != target.pos.value) {
            auto dist = (target.pos.value - unit.pos.value).getLength();
            int ticks = to!int(ceil(dist / speed));
            changeList.addMovement(unit, target.pos.value, ticks);
        }
        if (unit.pos == target.pos) {
            if (done !is null) {
                done(unit);
            } else if (removeOnArrive) {
                unit.ai = null;
            }
        }
    }
}

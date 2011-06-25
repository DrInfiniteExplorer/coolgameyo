
module unit;

import std.exception;
import std.stdio;

import changelist;
import pos;
import stolen.aabbox3d;
import util;
import world;

final class UnitType {
    string name;
    int x;
}

interface UnitAI {
    int tick(Unit* unit, ChangeList changeList);
}


struct Unit {

    bool opEquals(ref const(Unit) u) const {
        assert (0, "Implement Unit.opEquals or find where it's called and make not called!");
    }

    UnitAI ai;
    UnitType type;
    UnitPos pos;
    float rotation = 0; //radians


    float speed = 0.4;
    UnitPos destination;
    uint ticksToArrive;
    vec3d velocity;

    bool panics;

    float unitWidth = 0.7;
    float unitHeight = 1.5;
    float stepHeight = 0.5;

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
}



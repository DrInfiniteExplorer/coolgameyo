
module unit;

import std.conv;
import std.exception;
import std.math;
import std.stdio;
import std.array;

import changelist;
import modules.path;
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

    bool opEquals(ref const(Unit) u) const {
        assert (0, "Implement Unit.opEquals or find where it's called and make not called!");
    }

    UnitAI ai;
    UnitType type;
    UnitPos pos;
    float rotation = 0; //radians


    float speed = 0.1;
    UnitPos destination;
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
        if (unit.destination != target.pos) {
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



class PatrolAI : UnitAI {

    UnitPos a, b;
    Path path;
    PathModule pathModule;
    PathID id;
    bool toa, walking;

    this(Unit* u, UnitPos p, PathModule m) {
        a = u.pos;
        b = p;
        pathModule = m;

        id = pathModule.findPath(u.pos, b);
    }

    override void tick(Unit* unit, ChangeList changeList) {
        if (walking) {
            auto goal = toa ? a : b;
            auto p = path.path.back;
            write("going to ", toa ? "a=" : "b=", p, ", ");
            auto d = p.value.getDistanceFrom(unit.pos.value);

            if (d <= unit.speed) {
                writeln("arrived!");
                changeList.addMovement(unit, p, 1);
                if (p == goal) {
                    walking = false;
                    id = pathModule.findPath(unit.pos, toa ? b : a);
                    toa = !toa;
                } else {
                    path.path.popBack();
                }
            } else {
                auto dp = (p.value - unit.pos.value).setLength(unit.speed);
                writeln("from ", unit.pos,
                        " to ", UnitPos(unit.pos.value + dp));
                changeList.addMovement(unit, UnitPos(unit.pos.value + dp), 1);
            }
        } else {
            if (pathModule.pollPath(id, path)) {
                assert (path.path.length > 0);
                walking = true;
                tick(unit, changeList);
            } else {
                // wait for path module to finish our path :(
            }
        }
    }
}


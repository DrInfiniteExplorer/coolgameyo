

module ai.movetoai;

import std.conv;
import std.math;

import changes.changelist;
import unit;

import world.world;


class MoveToAI : UnitAI {

    Unit unit;
    Unit target;
    float speed;
    void delegate(Unit) done;
    bool removeOnArrive;
    this(Unit u, Unit targetUnit, float speed, void delegate(Unit) done = null, bool removeOnArrive=true){
        unit = u;
        target = targetUnit;
        this.speed = speed;
        this.done = done;
        this.removeOnArrive = removeOnArrive;
    }

    override int tick(ChangeList changeList) {
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
        return 0; // BUG: NO THOUGHT APPLIED HERE
    }
}


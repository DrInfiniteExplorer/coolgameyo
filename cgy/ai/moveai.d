module ai.moveai;

import std.array;
import std.conv;
import std.math;

import unit;
import pos;
import util.util;
import worldstate.worldproxy;

import modules.path;

struct Near {
    UnitPos pos;
}

Near near(UnitPos pos) {
    return Near(pos);
}

struct MoveAI {

    bool finished;
    bool failed;

    bool hasPath;
    Path path;
    PathID p;
    UnitPos[] goal;

    Unit unit;

    private this(Unit u, PathModule pathfinder) {
        unit = u;
        p = pathfinder.findPath((&unit.pos)[0..1], goal);
    }

    this(Unit unit, UnitPos pos, PathModule pathfinder) {
        goal ~= pos;
        this(unit, pathfinder);
    }
    this(Unit unit, Near near, PathModule pathfinder) {
        goal = neighbors(near.pos).dup;
        this(unit, pathfinder);
    }

    int tick(WorldProxy world, PathModule pathfinder) {
        assert (!finished, "Tried to tick move ai state which was finished");
        if (!hasPath) {
            if (!pathfinder.pollPath(p, path)) {
                return 0;
            }
            if (path.empty) {
                finished = true;
                failed = true;
                return 1;
            }
            hasPath = true;
        }

        auto next = path.path.back;

        auto d = next.value.getDistanceFrom(unit.pos.value);
        int ticks = to!int(ceil(d / unit.speed));
        world.moveUnit(unit, next, ticks);

        path.path.popBack();
        finished = path.empty;

        return ticks;
    }
}

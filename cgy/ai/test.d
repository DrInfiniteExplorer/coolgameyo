
module ai.test;

import std.algorithm;
import std.array;
import std.conv;
import std.math;

import ai.minetileai;
import changes.changelist;
import changes.worldproxy;
import graphics.debugging;
import mission;
import modules.path;
import util.pos;
import unit;
import util.util;



final class FuckingWrap(T) : UnitAI { // :---)
    T t;
    alias t this;

    override int tick(WorldProxy world, PathModule pathfinder) {
        t.tick(world, pathfinder);
    }
}

final class TestAI : UnitAI {

    bool inited_mine;
    MineTileAI mine;

    Unit unit;

    this(Unit u) {
        unit = u;
    }

    override int tick(WorldProxy world, PathModule pathfinder) {
        auto m = unit.mission;
        if (m.type == Mission.Type.nothing) {
            pragma(msg, "derp world.getMission(unit);");
            return 0;
        }
        
        if (m.type == Mission.Type.mine) {
            if (!inited_mine) {
                mine = MineTileAI(unit, m.target.tilePos, pathfinder);
                inited_mine = true;
            }
            scope (exit) {
                if (mine.finished) {
                    if (mine.failed) {
                        msg("Mine failed!");
                    }
                    unit.mission = Mission.none;
                    inited_mine = false;
                }
            }
            return mine.tick(world, pathfinder);
        }

        assert (0, text("Unit cant handle this type:", m.type));
    }
}

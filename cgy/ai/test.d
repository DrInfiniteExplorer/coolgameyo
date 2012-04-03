
module ai.test;

import std.algorithm;
import std.array;
import std.conv;
import std.math;

import changes.changelist;
import graphics.debugging;
import modules.path;
import unit;
import util.util;

import world.worldproxy;
import pos;

import mission;

import ai.minetileai;


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
            world.getMission(unit);
            return 1;
        }
        
        if (m.type == Mission.Type.mine) {
            if (!inited_mine) {
                mine = MineTileAI(unit, m.target.tilePos, pathfinder);
            }
            scope (exit) {
                if (mine.finished) {
                    unit.mission = Mission.none;
                    inited_mine = false;
                }
            }
            return mine.tick(world, pathfinder);
        }

        assert (0, text("Unit cant handle this type:", m.type));
    }
}

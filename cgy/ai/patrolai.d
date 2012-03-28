

module ai.patrolai;

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


class PatrolAI : UnitAI {

    Unit unit;
    UnitPos a, b;
    Path path;
    PathModule pathModule;
    PathID id;
    int lineId;
    bool toa, walking;
    int derp;

    this(Unit u, UnitPos p, PathModule m) {
        unit = u;
        a = u.pos;
        b = p;
        pathModule = m;

        id = pathModule.findPath(a, b);
    }

    override int tick(WorldProxy world) {
        derp++;
        if(derp < 2) return 0;
        derp = 0;
        if (walking) {
            auto goal = toa ? a : b;
            auto p = path.path.back;
            //write("going to ", toa ? "a=" : "b=", p, ", ");
            auto d = p.value.getDistanceFrom(unit.pos.value);

            //if (d <= unit.speed) {
            if (true) {
                    //msg("arrived!");
                world.moveUnit(unit, p, 1);
                if (p == goal) {
                    walking = false;
                    id = pathModule.findPath(toa ? a : b, toa ? b : a);
                    toa = !toa;
                } else {
                    path.path.popBack();
                }
                return 0;
            } else {
                auto dp = p.value - unit.pos.value;
                int ticks = to!int(floor(dp.getLength() / unit.speed));
                dp.setLength(ticks * unit.speed);
                //msg("from ", unit.pos,
                //        " to ", UnitPos(unit.pos.value + dp));
                world.moveUnit(
                        unit, UnitPos(unit.pos.value + dp), ticks);
                return ticks;
            }
        } else {
            if (pathModule.pollPath(id, path)) {
                if (path.path.length == 0) {
                    msg("COULDN'T FIND PATH DUDE");
                    return 100000;
                }

                //vec3d toVec(UnitPos p){
                //    return p.value;
                //}            // stringy function should work here
                auto positions = array(map!q{a.value}(path.path));
                if (lineId) {
                    removeLine(lineId);
                }
                lineId = addLine(positions, vec3f(1, 1, 0));
                walking = true;
                return tick(world);
            } else {
                // wait for path module to finish our path :(
                return 0;
            }
        }
    }
}


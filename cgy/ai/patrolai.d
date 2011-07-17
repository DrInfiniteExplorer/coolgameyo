

module ai.patrolai;

import std.algorithm;
import std.array;
import std.conv;
import std.math;

import changelist;
import graphics.debugging;
import modules.path;
import unit;
import util;
import world;


class PatrolAI : UnitAI {

    Unit* unit;
    UnitPos a, b;
    Path path;
    PathModule pathModule;
    PathID id;
    int lineId;
    bool toa, walking;

    this(Unit* u, UnitPos p, PathModule m) {
        unit = u;
        a = u.pos;
        b = p;
        pathModule = m;

        id = pathModule.findPath(u.pos, b);
    }

    override int tick(ChangeList changeList) {
        if (walking) {
            auto goal = toa ? a : b;
            auto p = path.path.back; //Apparently this .back requires the module std.array :P
            //write("going to ", toa ? "a=" : "b=", p, ", ");
            auto d = p.value.getDistanceFrom(unit.pos.value);

            if (d <= unit.speed) {
                //msg("arrived!");
                changeList.addMovement(unit, p, 1);
                if (p == goal) {
                    walking = false;
                    id = pathModule.findPath(unit.pos, toa ? b : a);
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
                changeList.addMovement(
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
                return tick(changeList);
            } else {
                // wait for path module to finish our path :(
                return 0;
            }
        }
    }
}


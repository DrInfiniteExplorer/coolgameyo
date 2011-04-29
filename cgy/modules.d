
module modules;

import std.stdio;
import std.exception;

import world;
import scheduler;
import pos;
import unit;

abstract class Module {
    void update(World world, Scheduler scheduler){
        //Possible cause if called: Change in function signature.
        enforce(0, "SHOULD NOT BE CALLED, EVER! :(");
    }
}

struct PathID {
    ulong id;
}
struct Path {
    TilePos[] derp;
}

class PathModule : Module {

    static struct PathFindState {
        void tick() {
            assert (false);
        }
    }

    ulong nextIDNum;

    Path[PathID] finishedPaths;

    PathFindState[] activeStates;

    PathID findPath(TilePos from, TilePos to) {
        assert (0);
        return PathID(nextIDNum++);
    }
    bool pollPath(PathID id, out Path path) {
        if (id !in finishedPaths) return false;

        path = finishedPaths[id];
        finishedPaths.remove(id);
        return true;
    }

    void update(World world, Scheduler scheduler) {
        //assert (false);
        foreach (state; activeStates) {
            scheduler.push(asyncTask({ return state.tick(); }));
        }
    }
}


class AIModule : Module, WorldListener {

    static struct UnitState {
        bool moving;
        int restTime;
    }

    PathModule pathmodule;

    UnitState[Unit*] states;

    this(PathModule pathmodule_) {
        pathmodule = pathmodule_;
    }

    void update(World world, Scheduler scheduler) {
        void pushUnitTick(Unit* unit, ref UnitState state) {
            scheduler.push(syncTask({
                        //state.restTime = unit.tick(state.restTime, pathmodule);
                        }));
        }

        foreach(unit ; world.getUnits()) {
            //writeln("U ", unit);
            if(unit.ai){
                Unit* ptr = unit;
                //writeln(unit);
                //writeln(unit.ai);
                scheduler.push(syncTask(
                    (const World w, ref CHANGE[] changes){
                        auto ai = ptr.ai;
                        //writeln(ptr);
                        //writeln(ai);
                        ai.tick(ptr, changes);
                    }
                ));
            }
        }

        Unit*[] movers = null;
        foreach (_unit, ref state; states) {
            auto unit = cast(Unit*)_unit; // BRUTAL HACK
            if (unit.panics) {
                pushUnitTick(unit, state);
                continue;
            }

            if (state.moving) {
                movers ~= unit;
            } else {
                if (--state.restTime == 0) {
                    pushUnitTick(unit, state);
                }
            }
        }

        if(movers !is null) {
            scheduler.push(syncTask((const World world) {
                            foreach (mover; movers) {
                                writeln("Herpi derpi movie unitie");
                                // world.lagMoveUnit(mover,
                                //    mover.pos + mover.direction * mover.speed); ???
                            }
                        }));
        }
    }

    override void notifySectorLoad(SectorNum) { }
    override void notifySectorUnload(SectorNum) { }
    override void notifyTileChange(TilePos) { }
}




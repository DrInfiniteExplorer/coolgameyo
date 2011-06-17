
module modules.ai;

import std.stdio;

import modules.module_;
import modules.path;

import unit;

class AIModule : Module, WorldListener {

    static struct UnitState {
        Unit* unit;
        bool moving;
        int restTime;
    }

    PathModule pathmodule;
    World world;

    UnitState[Unit*] states;

    this(PathModule pathmodule_, World w) {
        pathmodule = pathmodule_;
        world = w;
    }

    override void update(World world, Scheduler scheduler) {
        void pushUnitTick(Unit* unit, ref UnitState state) {
            scheduler.push(syncTask({
                        //state.restTime = unit.tick(state.restTime, pathmodule);
                        }));
        }

        foreach(unit ; world.getUnits()) {
            //writeln("U ", unit);
            if (unit.ai) {
                ((Unit* u) { // for new scope D: D: D:
                    auto scoped = u;
                    //writeln(unit);
                    //writeln(unit.ai);
                    scheduler.push(syncTask(
                        (const World w, ChangeList changeList){
                            auto ai = scoped.ai;
                            //writeln(ptr);
                            //writeln(cast(void*)ai);
                            ai.tick(scoped, changeList);
                        }
                    ));
                }) (unit);
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

        if (movers !is null) {
            scheduler.push(syncTask((const World world) {
                            foreach (mover; movers) {
                                writeln("Herpi derpi movie unitie");
                                // world.lagMoveUnit(mover,
                                //    mover.pos + mover.direction * mover.speed); ???
                            }
                        }));
        }
    }

    void addUnit(Unit* unit) {
        states[unit] = UnitState(unit, false, 0);
    }
    void removeUnit(Unit* unit) {
        states.remove(unit);
    }

    override void onAddUnit(SectorNum num, Unit* unit) {
        addUnit(unit);
    }
    override void onSectorLoad(SectorNum num) {
        foreach (unit; world.getSector(num).units) {
            addUnit(unit);
        }
    }
    override void onSectorUnload(SectorNum num) {
        foreach (unit; world.getSector(num).units) {
            removeUnit(unit);
        }
    }
    override void onTileChange(TilePos) { }
}


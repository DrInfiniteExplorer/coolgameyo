
module modules.ai;

import std.exception;
import std.stdio;

import modules.module_;
import modules.path;

import unit;

class AIModule : Module, WorldListener {

    static struct UnitState {
        Unit* unit;
        int restTime;
    }

    PathModule pathmodule;
    World world;

    UnitState[Unit*] states;

    this(PathModule pathmodule_, World w) {
        pathmodule = pathmodule_;
        world = w;
        world.addListener(this);

    }
    bool destroyed;
    ~this(){
        enforce(destroyed, "AIModule.destroyed not called!");
    }
    void destroy() {
        destroyed = true;
    }

    override void update(World world, Scheduler scheduler) {
        void push(ref UnitState state) {
            if (state.unit.ai is null) return;
            if (state.restTime > 0) {
                state.restTime -= 1;
                return;
            }
            assert (state.restTime == 0);
            scheduler.push(syncTask((const World world, ChangeList changelist) {
                        state.restTime = state.unit.tick(changelist);
                        }));
        }
        foreach (ref state; states) {
            push(state);
        }
    }

    void addUnit(Unit* unit) {
        states[unit] = UnitState(unit);
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


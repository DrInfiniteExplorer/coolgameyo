
module modules.ai;

import std.conv;
import std.exception;
import std.stdio;

import painlessjson : toJSON;

import changes.worldproxy;
import game;
import globals : g_worldPath;
import modules.module_;
import modules.path;
import unit;
import cgy.util.filesystem;
import cgy.util.util;
import scheduler : scheduler;



class AIModule : Module, WorldStateListener {

    static struct UnitState {
        Unit unit;
        int restTime;
        PathModule pathmodule;

        void runState(WorldProxy world) {
            restTime = unit.tick(world, pathmodule);
        }
    }

    static struct UnitStateJson {
        this(UnitState state) {
            unitId = state.unit.id;
            restTime = state.restTime;
        }
        uint unitId;
        int restTime;
    }

    PathModule pathmodule;
    WorldState world;

    UnitState[Unit] states;

    this(PathModule pathmodule_, WorldState w) {
        pathmodule = pathmodule_;
        world = w;
        world.addListener(this);
    }

    bool destroyed;
    ~this(){
        BREAK_IF(!destroyed);
    }
    void destroy() {
        destroyed = true;
    }

    JSONValue serializeState(UnitState state) {
        UnitStateJson data = UnitStateJson(state);
        return data.toJSON;
    }

    override void serializeModule() { //module interface
        JSONValue[] jsonStates;
        foreach (state; states) {
            jsonStates ~= serializeState(state);
        }
        auto jsonRoot = JSONValue(jsonStates);
        auto jsonString = jsonRoot.toString;
        mkdir(g_worldPath ~ "/modules/ai");
        std.file.write(g_worldPath ~ "/modules/ai/states.json", jsonString);

    }
    override void deserializeModule() { //module interface
        pragma(msg, "Implement AIModule.deserializeModule()");
    }
    override void update(WorldState world) { //module interface
        foreach (ref state; states) {
            if (state.unit.ai is null) continue;
            if (state.restTime > 0) {
                state.restTime -= 1;
                continue;
            }
            assert (state.restTime == 0);
            scheduler.push(task(&state.runState));
        }
    }

    void addUnit(Unit unit) {
        states[unit] = UnitState(unit, 0, pathmodule);
    }
    void removeUnit(Unit unit) {
        states.remove(unit);
    }

    override void onAddUnit(SectorNum num, Unit unit) {
        addUnit(unit);
    }
    void onAddEntity(SectorNum, Entity) { }

    override void onSectorLoad(SectorNum num) {
    }
    override void onSectorUnload(SectorNum num) {
    }
    override void onTileChange(TilePos) { }
    void onUpdateGeometry(TilePos tilePos) {
    }
    void onBuildGeometry(SectorNum sectorNum) {
    }
}


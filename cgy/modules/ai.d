
module modules.ai;

import std.conv;
import std.exception;
import std.stdio;

import json;

import modules.module_;
import modules.path;

import unit;
import util.util;
import util.filesystem;


class AIModule : Module, WorldListener {

    static struct UnitState {
        Unit* unit;
        int restTime;
    }
    
    static struct UnitStateJson {
        this(UnitState state) {
            unitId = state.unit.unitId;
            restTime = state.restTime;
        }
        uint unitId;
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
        BREAK_IF(!destroyed);
    }
    void destroy() {
        destroyed = true;
    }

    Value serializeState(UnitState state) {
        UnitStateJson data = UnitStateJson(state);
        return encode(data);
    }
    
    override void serializeModule() { //module interface
        Value[] jsonStates;
        foreach( state ; states ) {
            jsonStates ~= serializeState(state);
        }
        auto jsonRoot = Value(jsonStates);
        auto jsonString = to!string(jsonRoot);	
	    jsonString = json.prettyfyJSON(jsonString);
        mkdir("saves/current/modules/ai");
        std.file.write("saves/current/modules/ai/states.json", jsonString);
        
    }
    override void deserializeModule() { //module interface
        BREAKPOINT;
    }
    override void update(World world, Scheduler scheduler) { //module interface
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
	void onAddEntity(SectorNum, Entity) { }
	
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
    void onUpdateGeometry(TilePos tilePos) {
    }
    void onBuildGeometry(SectorNum sectorNum) {
    }

}


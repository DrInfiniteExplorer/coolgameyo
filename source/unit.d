
module unit;

import std.exception;
import std.stdio;
import std.json : JSONValue;

import changes.changelist;
import changes.worldproxy;
import clan;
import clans;
import inventory;
import mission;
import cgy.util.pos;
import cgy.stolen.aabbox3d;

import unittypemanager;
import cgy.math.vector : vec3d;
import worldstate.worldstate;



import modules.path;

immutable INVALID_UNIT_ID = 0;
shared int g_UnitCount = INVALID_UNIT_ID; //Global counter of units. Make shared static variable in Game-class?


interface UnitAI {
    int tick(WorldProxy world, PathModule pathfinder);
}

struct Demand {
    float current;

    float max;
    float critical;

    float r;

    this(float c, float m, float cc, float rr=1./3) {
        current = c;
        max = m;
        critical = cc;
        r = rr;
    }

    void tick() { current -= r; }

    //alias current this;
}

Unit newUnit() {
    auto id = core.atomic.atomicOp!"+="(g_UnitCount, 1);
    auto unit = new Unit(id);
    return unit;
}

final class Unit {

    bool opEquals(ref const(Unit) u) const {
        assert (0, "Implement Unit.opEquals or find where it's called and make not called!");
    }

    struct UnitData {
        uint id;
        Demand hunger = Demand(100, 100, 10);
        Demand thirst = Demand(100, 100, 20);
        UnitPos pos;
        float rotation = 0; //radians
        float speed = 1.0;
        UnitPos destination;
        uint ticksToArrive = 0;
        vec3d velocity;
        bool panics;
        float unitWidth = 0.7;
        float unitHeight = 1.5;
        float stepHeight = 0.5;



    };

    UnitData unitData;
    alias unitData this;

    UnitAI ai;
    UnitType type;
    Clan clan;
    Inventory inventory;

    Mission mission;

    this(uint _id) {
        id = _id;
        inventory = new Inventory;
    }


    JSONValue _toJSON() {
        auto val = unitData.toJSON;
        val["typeId"] = type.id;
        val["clanId"] = clan.clanId;
        //Add ai
        return val;
    }
    void fromJSON(JSONValue val) {
        //msg(val);
        unitData = val.fromJSON!(typeof(unitData));

        int typeId = val["typeId"].fromJSON!int;
        int clanId = val["clanId"].fromJSON!int;

        type = unitTypeManager.byID(cast(ushort)typeId);
        Clans().getClanById(clanId).addUnit(this);

        inventory = new Inventory(); // TODO: RAWR!!
        //Add ai
    }




    int tick(WorldProxy world, PathModule pathfinder) {
        this.hunger.tick();
        this.thirst.tick();
        return ai.tick(world, pathfinder);
    }

    //Returns the bounding box of the unit, in world space.
    //If no parameter is passed, the units position is used as base,
    //otherwise the passed position is padded with the unit-size.
    aabbox3d!(double) aabb(const(vec3d)* v = null) const @property {
        if(v is null){
            v = &this.pos.value;
        }
        auto minPos = (*v)  - vec3d(this.unitWidth * 0.5, this.unitWidth*0.5, 0.5); // Unitpos is from center of tile
        auto maxPos = minPos + vec3d(this.unitWidth, this.unitWidth, this.unitHeight);
        return aabbox3d!double(minPos, maxPos);
    }
}



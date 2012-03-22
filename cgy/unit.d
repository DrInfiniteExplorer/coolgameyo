
module unit;

import std.exception;
import std.stdio;

import json;
import changes.changelist;
import pos;
import stolen.aabbox3d;

import world.world;
import clan;
import util.util;
import unittypemanager;
import inventory;

import world.worldproxy;

shared int g_UnitCount = 0; //Global counter of units. Make shared static variable in Game-class?


interface UnitAI {
    int tick(WorldProxy world);
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

    alias current this;
}

Unit newUnit() {
    auto unit = new Unit;
    unit.unitId = g_UnitCount;
    g_UnitCount++;
    unit.inventory = new Inventory();
    return unit;
}

class Unit {

    bool opEquals(ref const(Unit) u) const {
        assert (0, "Implement Unit.opEquals or find where it's called and make not called!");
    }

    struct UnitData {
        uint unitId;
        Demand hunger = Demand(100, 100, 10);
        Demand thirst = Demand(100, 100, 20);
        UnitPos pos;
        float rotation = 0; //radians
        float speed = 1;
        UnitPos destination;
        uint ticksToArrive;
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



    Value toJSON() {
        Value val = encode(unitData);
        if (clan !is null) {
            val["clanId"] = Value(clan.clanId);
        }
        /*if (type !is null) {
          val["unitTypeId"] = Value(type.name);
          }*/
        //Add ai
        return val;
    }
    void fromJSON(Value val) {
        read(unitData, val);
        if ("clanId" in val) {
            //int clanId;
            //read(clanId, val["clanId"]);
            //BREAKPOINT;
            //Since units are stored with their clan, and deserialized by their clan, we dont need
            //to care about a units serialized clanid. :)
        }
        if ("unitTypeId" in val) {
            int unitTypeId;
            read(unitTypeId, val["unitTypeId"]);
            BREAKPOINT;
        }
        inventory = new Inventory(); // TODO: RAWR!!
        //Add ai
    }




    int tick(WorldProxy world) {
        this.hunger.tick();
        this.thirst.tick();
        return ai.tick(world);
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



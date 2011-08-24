
module entity;

import std.exception;
import std.stdio;

import json;
import changelist;
import pos;
import stolen.aabbox3d;
import util;
import world;
import clan;
import entitytypemanager;

shared int g_EntityCount = 0; //Global counter of entities. Make shared static variable in Game-class?

Entity* newEntity() {
    auto entity = new Entity;
    entity.entityId = g_EntityCount;
    g_EntityCount++;
    return entity;
}

struct Entity {

    bool opEquals(ref const(Entity) o) const {
        assert (0, "Implement Entity.opEquals or find where it's called and make not called!");
    }

    struct EntityData {
        uint entityId;
        EntityPos pos;
        float rotation = 0; //radians

        float entityWidth = 0.7;
        float entityHeight = 1.5;        
    }
    EntityData entityData;
    alias entityData this;

    EntityType type;
    Clan clan;
    
    Value toJSON() {
        Value val = encode(entityData);
        if (clan !is null) {
            val["clanId"] = Value(clan.clanId);
        }
/*        if (type !is null) {
            val["unitTypeId"] = Value(type.name);
        }*/
        //Add ai
        return val;
    }
    void fromJSON(Value val) {
        read(entityData, val);
        if ("clanId" in val) {
            int clanId;
            read(clanId, val["clanId"]);
            BREAKPOINT;
        }
        if ("unitTypeId" in val) {
            int unitTypeId;
            read(unitTypeId, val["unitTypeId"]);
            BREAKPOINT;
        }
        //Add ai
    }
        
	

    int tick(ChangeList changeList) {
        
        return 1;
    }

    //Returns the bounding box of the unit, in world space.
    //If no parameter is passed, the units position is used as base,
    //otherwise the passed position is padded with the unit-size.
    aabbox3d!(double) aabb(const(vec3d)* v = null) const @property {
        if(v is null){
            v = &entityData.pos.value;
        }
        auto minPos = (*v)  - vec3d(entityData.entityWidth * 0.5, entityData.entityWidth*0.5, 0);
        auto maxPos = minPos + vec3d(entityData.entityWidth, entityData.entityWidth, entityData.entityHeight);
        return aabbox3d!double(minPos, maxPos);
    }
}



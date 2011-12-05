
module entities.entity;

import std.exception;
import std.stdio;
import std.math;

import json;
import changes.changelist;
import pos;
import stolen.aabbox3d;
import util.util;
import world.world;
import clan;
import entitytypemanager;
import light;

shared int g_EntityIdCounter = 0; // To know what the id for the next entity will be


Entity newEntity() {
    auto entity = new Entity;
    entity.entityId = g_EntityIdCounter;
    g_EntityIdCounter++;
    return entity;
}

class Entity {

    bool opEquals(ref const(Entity) o) const {
        assert (0, "Implement Entity.opEquals or find where it's called and make not called!");
    }
	int opCmp(ref const(Entity) other) const {
		return cast(int)sgn(cast(long)entityData.entityId - cast(long)other.entityId);
	}

    struct EntityData {
        int entityId;
        EntityPos pos;
        float rotation = 0; //radians
		bool isDropped = false;

        float entityWidth = 1.0;
        float entityHeight = 1.0;
    }
    EntityData entityData;
    alias entityData this;

    EntityType type;
    Clan clan;
    LightSource light;

	void deconstruct() {
		entityData.isDropped = true;
	}
	
    Value toJSON() {
        Value val = encode(entityData);
        
        val["entityTypeId"] = Value(type.id);
        
        return val;
    }
    void fromJSON(Value val, EntityTypeManager entityTypeManager) {
        read(entityData, val);
        
        if ("entityTypeId" in val) {
            int entityTypeId;
            read(entityTypeId, val["entityTypeId"]);
			type = entityTypeManager.byID(cast(ushort)entityTypeId);
        }
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
        auto minPos = (*v)  - vec3d(entityData.entityWidth * 0.5, entityData.entityWidth*0.5, 0.5); // Unitpos is from center of tile
        auto maxPos = minPos + vec3d(entityData.entityWidth, entityData.entityWidth, entityData.entityHeight);
        return aabbox3d!double(minPos, maxPos);
    }
}



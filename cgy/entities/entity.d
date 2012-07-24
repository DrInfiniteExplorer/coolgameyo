
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

import inventory;

import entities.growable;
import entities.placeable;
import entities.workshop;


shared int g_entityCount;


Entity newEntity() {
    auto entity = new Entity;
    entity.entityId = g_entityCount;
    g_entityCount++;
    return entity;
}

final class Entity {

    bool opEquals(ref const(Entity) o) const {
        assert (0, "Implement Entity.opEquals or find where it's called and make not called!");
    }
    int opCmp(ref const(Entity) other) const {
        return cast(int)sgn(cast(long)entityData.entityId
                - cast(long)other.entityId);
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

    // these need serairarleinzlaeniton IN SOME WAY
    Workshop* workshop;
    Placeable* placeable;
    Growable* growable;

    Inventory inventory;

    bool shouldTick() const @property {
        return workshop != null || growable != null;
    }

    void deconstruct() {
        entityData.isDropped = true;
    }

    Value toJSON() {
        Value val = encode(entityData);

        val["entityTypeId"] = Value(type.id);

        return val;
    }
    void fromJSON(Value val, EntityTypeManager entityTypeManager) {
        val.read(entityData);

        if ("entityTypeId" in val) {
            int entityTypeId;
            val["entityTypeId"].read(entityTypeId);
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



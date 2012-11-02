
module entities.entity;

import std.exception;
import std.stdio;
import std.math;

import clan;
import clans;
import changes.changelist;
import entitytypemanager;
import light;
import json;
import util.pos;
import stolen.aabbox3d;
import util.util;
import worldstate.worldstate;
import changes.worldproxy;

import inventory;

import entities.treelikeinstance;
import entities.placeable;
import entities.workshop;


shared int g_entityCount;

WorldProxy entityCreationProxy;
private void createEntity(Entity entity, EntityType type, WorldState world) {
    if(entityCreationProxy is null) {
        entityCreationProxy = new WorldProxy(world);
    }
    entity.type = type;
    entity.createTreeLikeEntity(world, entityCreationProxy);
}

Entity newEntity(Value serializedEntity, WorldState world) {
    auto ent = newEntity();
    ent.deserialize(serializedEntity, world);
    return ent;
}

//When creating an entity trough this method, dont forget to
// add it to a changelist with createEntity(ent, json.Value). the apply-
// -function there deserializes, and deserialization binds and
// creates the actual non-basic entity data and connections.
Entity newEntity(EntityType type) {
    auto ent = newEntity();
    ent.type = type;
    return ent;
}

private Entity newEntity() {
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

        TilePos[] ownedTiles;
    }
    EntityData entityData;
    alias entityData this;

    EntityType type;
    Clan clan;
    LightSource light;

    // these need serairarleinzlaeniton IN SOME WAY
    Workshop* workshop;
    Placeable* placeable;

    mixin TreeLike;


    Inventory inventory;

    bool shouldTick() const @property {
        return workshop != null || treelike !is null;
    }

    void deconstruct() {
        entityData.isDropped = true;
    }

    Value toJSON() {
        Value val = encode(entityData);

        val.populateJSONObject("entityTypeId", type.id);
        if(clan !is null) {
            val.populateJSONObject("clanId", clan.clanId);
        }

        return val;
    }

    //Formerly this. Only allow easy encoding of entities, deserialization must go trough controlled means.
    //void fromJSON(Value val) {

    void deserialize(Value val, WorldState world) {
        val.read(entityData);

        enforce("entityTypeId" in val, "Serialized entity does not have entityTypeId variable!");
        enforce("clanId" in val, "Serialized entity does not have clanId variable!");
        int entityTypeId;
        int clanId;
        val.readJSONObject("entityTypeId", &entityTypeId,
                           "clanId", &clanId);
        auto entityTypeManager = EntityTypeManager();
        auto type = entityTypeManager.byID(cast(ushort)entityTypeId);

        createEntity(this, type, world);

        Clans().getClanById(clanId).addEntity(this);


    }



    int tick(WorldProxy proxy) {
        treelikeTick(proxy);

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



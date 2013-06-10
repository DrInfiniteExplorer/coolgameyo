
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
import util.memory;
import util.util;
import worldstate.worldstate;
import changes.worldproxy;

import inventory;

import entities.treelikeinstance;
import entities.placeable;
import entities.workshop;

import tiletypemanager;


immutable INVALID_ENTITY_ID = 0;
shared int g_entityCount = INVALID_ENTITY_ID;

Entity newEntity(string typeName) {
    auto type = entityTypeManager.byName(typeName);
    BREAK_IF(type is null);
    
    auto id = core.atomic.atomicOp!"+="(g_entityCount, 1);
    auto entity = new Entity(id, type);
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

    Inventory inventory;

    mixin TreeLike;

    this(uint id, EntityType _type) {
        entityId = id;
        type = _type;
        if(type.hasTreelike) {
            treelike = new TreelikeInstance;
        }
    }


    bool shouldTick() const @property {
        return workshop != null || treelike !is null;
    }

    void deconstruct() {
        entityData.isDropped = true;
    }


    void serializeBinary(BinaryWriter writer) {
        writer.write(entityId);
        writer.write(type.id);
        writer.write(clan.clanId);
        writer.write(entityData);
        serializeBinaryTreelike(writer);
    }

    static Entity deserializeBinary(BinaryReader reader) {
        auto entityId = reader.read!int;
        auto typeId = reader.read!int;
        auto clanId = reader.read!int;
        auto type = entityTypeManager.byId(typeId);
        auto clan = Clans().getClanById(clanId);
        auto ent = new Entity(entityId, type);
        reader.read(ent.entityData);
        ent.deserializeBinaryTreelike(reader);

        clan.addEntity(ent);
        return ent;
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
        auto width = vec3d(entityData.entityWidth * 0.5, entityData.entityWidth*0.5, 0.5);
        auto minPos = (*v)  - width; // Unitpos is from center of tile
        auto maxPos = minPos + vec3d(entityData.entityWidth, entityData.entityWidth, entityData.entityHeight);
        BREAKPOINT;
        assert(0);
        //return aabbox3d!double(minPos, maxPos);
    }
}



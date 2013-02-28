module changes.changes;

import clan;
import entities.entity;
import inventory;
import json;
import util.pos;
import unit;
import util.util;
import worldstate.worldstate;



struct SetTile {
    TilePos tp;
    Tile t;

    void apply(WorldState world) {
        world.unsafeSetTile(tp, t);
    }
}
struct DamageTile {
    TilePos tp;
    int damage;

    void apply(WorldState world) {
        auto t = world.getTile(tp);
        if (t.hitpoints <= damage) {
            world.unsafeRemoveTile(tp);
        } else {
            t.hitpoints -= damage;
            world.unsafeSetTile(tp, t);
        }
    }
}
struct RemoveTile {
    TilePos tp;

    void apply(WorldState world) {
        world.unsafeRemoveTile(tp);
    }
}

struct CreateUnit {

    this(Unit _u) {
        /*
        u = _u;
        serialized = encode(u);
        */
    }

    //Unit u;
    uint unitId;
    //Value serialized;

    void apply(WorldState world) {
        /*
        if(u is null) {
            import std.exception;
            enforce(0, "Implement creating of units over network");
        }
        */
    }
}
struct RemoveUnit {
    //Unit u;
    uint unitId;

    void apply(WorldState world) {
        assert(0);
    }
}
struct MoveUnit {
    uint unitId;
    UnitPos destination;
    uint ticksToArrive;

    this(Unit unit, UnitPos dest, uint toArrive) {
        unitId = unit.id;
        destination = dest;
        ticksToArrive = toArrive;
    }

    void apply(WorldState world) {
        import clans;
        auto unit = Clans().getUnitById(unitId);
        world.unsafeMoveUnit(unit, destination, ticksToArrive);
    }
}

struct SetIntent {
    //Unit u;
    uint unitId;
    string id;
    string description;
 
    void apply(WorldState world) {
        assert(0);
    }
}
struct SetAction {
    //Unit u;
    uint unitId;
    string id;
    string description;

    void apply(WorldState world) {
        assert(0);
    }
}

struct CreateEntity {
/*
    this(Value value) {
        e = null;
        serializedData = value;
    }

    this(Entity _e, Value params) {
        e = _e;
        serializedData = encode(e);
        foreach(key, val ; params.asObject()) {
            serializedData[key] = val;
        }
    }

    Entity e;
    Value serializedData;

    void apply(WorldState world) {
        if(e is null) {
            auto entity = newEntity(serializedData, world);
        } else {
            e.deserialize(serializedData, world);
        }
    }
    */

    uint entityId;
    uint entityTypeId;
    uint clanId;
    EntityPos entityPos;
    void apply(WorldState world) {
        BREAKPOINT;
    }
}
struct RemoveEntity {
    //Entity e;
    uint entityId;

    void apply(WorldState world) {
        assert(0);
    }
}
struct MoveEntity {
    //Entity e;
    uint entityId;
    EntityPos pos;

    void apply(WorldState world) {
        assert(0);
    }
}
struct PickupEntity {
    //Entity e;
    uint entityId;
    //Inventory a;

    void apply(WorldState world) {
        assert(0);
    }
}
struct DepositEntity {
    //Entity e;
    uint entityId;
    //Inventory a, b;

    void apply(WorldState world) {
        assert(0);
    }
}
struct ActivateEntity {
    //Unit activator;
    //Entity e;
    uint unitId;
    uint entityId;

    void apply(WorldState world) {
        assert(0);
    }
}

struct GetMission {
    //Unit unit;
    uint unitId;

    void apply(WorldState world) {
        //unit.mission = unit.clan.unsafeGetMission();
    }
}

struct DesignateMine {
    //Clan clan;
    uint clanId;
    TilePos pos;

    void apply(WorldState world) {
        //clan.unsafeDesignateMinePos(pos);
    }
}



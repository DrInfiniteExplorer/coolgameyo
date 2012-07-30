module changes.changes;

import worldstate.worldstate;
import pos;
import unit;
import entities.entity;
import inventory;

import clan;

import util.util;

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
    Unit u;

    void apply(WorldState world) {
        assert(0);
    }
}
struct RemoveUnit {
    Unit u;

    void apply(WorldState world) {
        assert(0);
    }
}
struct MoveUnit {
    Unit unit;
    UnitPos destination;
    uint ticksToArrive;

    void apply(WorldState world) {
        world.unsafeMoveUnit(unit, destination, ticksToArrive);
    }
}

struct SetIntent {
    Unit u;
    string id;
    string description;

    void apply(WorldState world) {
        assert(0);
    }
}
struct SetAction {
    Unit u;
    string id;
    string description;

    void apply(WorldState world) {
        assert(0);
    }
}

struct CreateEntity {
    Entity e;

    void apply(WorldState world) {
        assert(0);
    }
}
struct RemoveEntity {
    Entity e;

    void apply(WorldState world) {
        assert(0);
    }
}
struct MoveEntity {
    Entity e;
    EntityPos pos;

    void apply(WorldState world) {
        assert(0);
    }
}
struct PickupEntity {
    Entity e;
    Inventory a;

    void apply(WorldState world) {
        assert(0);
    }
}
struct DepositEntity {
    Entity e;
    Inventory a, b;

    void apply(WorldState world) {
        assert(0);
    }
}
struct ActivateEntity {
    Unit activator;
    Entity e;

    void apply(WorldState world) {
        assert(0);
    }
}

struct GetMission {
    Unit unit;

    void apply(WorldState world) {
        unit.mission = unit.clan.unsafeGetMission();
    }
}

struct DesignateMine {
    Clan clan;
    TilePos pos;

    void apply(WorldState world) {
        clan.unsafeDesignateMinePos(pos);
    }
}


// Only implemented by experimental or semi-hacky classes.
// List of such classes:
//  FPSControlAI
interface CustomChange {
    void apply(WorldState world);
}

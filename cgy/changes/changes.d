module changes.changes;

import world.world;
import pos;
import unit;
import entities.entity;
import inventory;

import clan;

struct SetTile {
    TilePos tp;
    Tile t;

    void apply(World world) {
        world.unsafeSetTile(tp, t);
    }
}
struct DamageTile {
    TilePos tp;
    int damage;

    void apply(World world) {
        assert(0);
    }
}
struct RemoveTile {
    TilePos tp;

    void apply(World world) {
        assert(0);
    }
}

struct CreateUnit {
    Unit u;

    void apply(World world) {
        assert(0);
    }
}
struct RemoveUnit {
    Unit u;

    void apply(World world) {
        assert(0);
    }
}
struct MoveUnit {
    Unit unit;
    UnitPos destination;
    uint ticksToArrive;

    void apply(World world) {
        world.unsafeMoveUnit(unit, destination, ticksToArrive);
    }
}

struct SetIntent {
    Unit u;
    string id;
    string description;

    void apply(World world) {
        assert(0);
    }
}
struct SetAction {
    Unit u;
    string id;
    string description;

    void apply(World world) {
        assert(0);
    }
}

struct CreateEntity {
    Entity e;

    void apply(World world) {
        assert(0);
    }
}
struct RemoveEntity {
    Entity e;

    void apply(World world) {
        assert(0);
    }
}
struct MoveEntity {
    Entity e;
    EntityPos pos;

    void apply(World world) {
        assert(0);
    }
}
struct PickupEntity {
    Entity e;
    Inventory a;

    void apply(World world) {
        assert(0);
    }
}
struct DepositEntity {
    Entity e;
    Inventory a, b;

    void apply(World world) {
        assert(0);
    }
}
struct ActivateEntity {
    Unit activator;
    Entity e;

    void apply(World world) {
        assert(0);
    }
}

struct GetMission {
    Unit unit;

    void apply(World world) {
        unit.mission = unit.clan.unsafeGetMission();
    }
}

struct DesignateMine {
    Clan clan;
    TilePos pos;

    void apply(World world) {
        clan.unsafeDesignateMinePos(pos);
    }
}


// Only implemented by experimental or semi-hacky classes.
// List of such classes:
//  FPSControlAI
interface CustomChange {
    void apply(World world);
}

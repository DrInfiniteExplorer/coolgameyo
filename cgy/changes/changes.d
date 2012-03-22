module changes.changes;

import world.world;
import pos;
import unit;
import entities.entity;
import inventory;

struct SetTile {
    TilePos tp;
    Tile t;
}
struct DamageTile {
    TilePos tp;
    int damage;
}
struct RemoveTile {
    TilePos tp;
}

struct CreateUnit {
    Unit u;
}
struct RemoveUnit {
    Unit u;
}
struct MoveUnit {
    Unit unit;
    UnitPos destination;
    uint ticksToArrive;
}

struct SetIntent {
    Unit u;
    string id;
    string description;
}
struct SetAction {
    Unit u;
    string id;
    string description;
}

struct CreateEntity {
    Entity e;
}
struct RemoveEntity {
    Entity e;
}
struct MoveEntity {
    Entity e;
    EntityPos pos;
}
struct PickupEntity {
    Entity e;
    Inventory a;
}
struct DepositEntity {
    Entity e;
    Inventory a, b;
}
struct ActivateEntity {
    Unit activator;
    Entity e;
}

// Only implemented by experimental or semi-hacky classes.
// List of such classes:
//  FPSControlAI
interface CustomChange {
    void apply(World world);
}

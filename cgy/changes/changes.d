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

    ubyte[] toBytes() {
        return (cast(ubyte*)&this)[0 .. this.sizeof];
    }
    size_t fromBytes(ubyte *ptr) {
        this = *(cast(typeof(&this))ptr);
        return this.sizeof;
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
    ubyte[] toBytes() {
        return (cast(ubyte*)&this)[0 .. this.sizeof];
    }
    size_t fromBytes(ubyte *ptr) {
        this = *(cast(typeof(&this))ptr);
        return this.sizeof;
    }

}
struct RemoveTile {
    TilePos tp;

    void apply(WorldState world) {
        world.unsafeRemoveTile(tp);
    }
    ubyte[] toBytes() {
        return (cast(ubyte*)&this)[0 .. this.sizeof];
    }
    size_t fromBytes(ubyte *ptr) {
        this = *(cast(typeof(&this))ptr);
        return this.sizeof;
    }

}

struct CreateClan {
    Clan clan;

    struct Inner {
        uint id;
    };
    Inner inner;
    alias inner this;

    this(Clan _clan) {
        clan = _clan;
        id = clan.clanId;
    }

    void apply(WorldState world) {
        import clans : Clans;
        clan = Clans().getClanById(id);
        if(clan) return; // Is on server, yay.
        if(clan is null) {
            clan = new NormalClan(id);
        }
        clan.init(world);
    }
    ubyte[] toBytes() {
        return (cast(ubyte*)&inner)[0 .. inner.sizeof];
    }
    size_t fromBytes(ubyte *ptr) {
        inner = *(cast(typeof(&inner))ptr);
        return inner.sizeof;
    }

}

struct CreateUnit {

    Unit unit;

    struct Inner {
        uint unitId;
        uint typeId;
        uint clanId;
        UnitPos pos;
    };
    Inner inner;
    alias inner this;


    this(Unit _unit) {
        unit = _unit;
        unitId = unit.id;
        typeId = unit.type.id;
        clanId = unit.clan.clanId;
        pos = unit.pos;
    }

    //Value serialized;

    void apply(WorldState world) {
        if(unit is null) {
            unit = new Unit(unitId);
            unit.pos = pos;
            import unittypemanager;
            unit.type = unitTypeManager.byID(cast(ushort)typeId);
        }
        import clan : Clans;
        Clans().getClanById(clanId).addUnit(unit);
    }
    ubyte[] toBytes() {
        return (cast(ubyte*)&inner)[0 .. inner.sizeof];
    }
    size_t fromBytes(ubyte *ptr) {
        inner = *(cast(typeof(&inner))ptr);
        return inner.sizeof;
    }


}
struct RemoveUnit {
    //Unit u;
    uint unitId;

    void apply(WorldState world) {
        assert(0);
    }
    ubyte[] toBytes() {
        return (cast(ubyte*)&this)[0 .. this.sizeof];
    }
    size_t fromBytes(ubyte *ptr) {
        this = *(cast(typeof(&this))ptr);
        return this.sizeof;
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
    ubyte[] toBytes() {
        return (cast(ubyte*)&this)[0 .. this.sizeof];
    }
    size_t fromBytes(ubyte *ptr) {
        this = *(cast(typeof(&this))ptr);
        return this.sizeof;
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
    ubyte[] toBytes() {
        return (cast(ubyte*)&this)[0 .. this.sizeof];
    }
    size_t fromBytes(ubyte *ptr) {
        this = *(cast(typeof(&this))ptr);
        return this.sizeof;
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
    ubyte[] toBytes() {
        return (cast(ubyte*)&this)[0 .. this.sizeof];
    }
    size_t fromBytes(ubyte *ptr) {
        this = *(cast(typeof(&this))ptr);
        return this.sizeof;
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
    ubyte[] toBytes() {
        return (cast(ubyte*)&this)[0 .. this.sizeof];
    }
    size_t fromBytes(ubyte *ptr) {
        this = *(cast(typeof(&this))ptr);
        return this.sizeof;
    }

}
struct RemoveEntity {
    //Entity e;
    uint entityId;

    void apply(WorldState world) {
        assert(0);
    }
    ubyte[] toBytes() {
        return (cast(ubyte*)&this)[0 .. this.sizeof];
    }
    size_t fromBytes(ubyte *ptr) {
        this = *(cast(typeof(&this))ptr);
        return this.sizeof;
    }

}
struct MoveEntity {
    //Entity e;
    uint entityId;
    EntityPos pos;

    void apply(WorldState world) {
        assert(0);
    }
    ubyte[] toBytes() {
        return (cast(ubyte*)&this)[0 .. this.sizeof];
    }
    size_t fromBytes(ubyte *ptr) {
        this = *(cast(typeof(&this))ptr);
        return this.sizeof;
    }

}
struct PickupEntity {
    //Entity e;
    uint entityId;
    //Inventory a;

    void apply(WorldState world) {
        assert(0);
    }
    ubyte[] toBytes() {
        return (cast(ubyte*)&this)[0 .. this.sizeof];
    }
    size_t fromBytes(ubyte *ptr) {
        this = *(cast(typeof(&this))ptr);
        return this.sizeof;
    }

}
struct DepositEntity {
    //Entity e;
    uint entityId;
    //Inventory a, b;

    void apply(WorldState world) {
        assert(0);
    }
    ubyte[] toBytes() {
        return (cast(ubyte*)&this)[0 .. this.sizeof];
    }
    size_t fromBytes(ubyte *ptr) {
        this = *(cast(typeof(&this))ptr);
        return this.sizeof;
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
    ubyte[] toBytes() {
        return (cast(ubyte*)&this)[0 .. this.sizeof];
    }
    size_t fromBytes(ubyte *ptr) {
        this = *(cast(typeof(&this))ptr);
        return this.sizeof;
    }

}

struct GetMission {
    //Unit unit;
    uint unitId;

    void apply(WorldState world) {
        //unit.mission = unit.clan.unsafeGetMission();
    }
    ubyte[] toBytes() {
        return (cast(ubyte*)&this)[0 .. this.sizeof];
    }
    size_t fromBytes(ubyte *ptr) {
        this = *(cast(typeof(&this))ptr);
        return this.sizeof;
    }

}

struct DesignateMine {
    //Clan clan;
    uint clanId;
    TilePos pos;

    void apply(WorldState world) {
        //clan.unsafeDesignateMinePos(pos);
    }
    ubyte[] toBytes() {
        return (cast(ubyte*)&this)[0 .. this.sizeof];
    }
    size_t fromBytes(ubyte *ptr) {
        this = *(cast(typeof(&this))ptr);
        return this.sizeof;
    }

}



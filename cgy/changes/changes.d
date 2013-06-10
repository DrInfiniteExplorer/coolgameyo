module changes.changes;

import std.conv : to;

import clan;
import clans : Clans;
import entities.entity;
import inventory;
import json;
import util.pos;
import unit;
import unittypemanager : unitTypeManager;
import util.filesystem;
import util.memory : BinaryWriter, BinaryMemoryReader;
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
    uint id;

    this(Clan clan) {
        id = clan.clanId;
    }

    void apply(WorldState world) {
        import clans : Clans;
        auto clan = new NormalClan(id);
        clan.init(world);
    }
    ubyte[] toBytes() {
        return (cast(ubyte*)&this)[0 .. this.sizeof];
    }
    size_t fromBytes(ubyte *ptr) {
        this = *(cast(typeof(&this))ptr);
        return this.sizeof;
    }
}

struct CreateUnit {

    uint unitId;
    uint typeId;
    uint clanId;
    UnitPos pos;


    this(Unit unit) {
        unitId = unit.id;
        typeId = unit.type.id;
        clanId = unit.clan.clanId;
        pos = unit.pos;
    }

    //Value serialized;

    void apply(WorldState world) {
        auto unit = new Unit(unitId);
        unit.pos = pos;
        unit.type = unitTypeManager.byID(cast(ushort)typeId);
        Clans().getClanById(clanId).addUnit(unit);
    }
    ubyte[] toBytes() {
        return (cast(ubyte*)&this)[0 .. this.sizeof];
    }
    size_t fromBytes(ubyte *ptr) {
        this = *(cast(typeof(&this))ptr);
        return this.sizeof;
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

    uint id;
    ubyte[] serialized;

    this(Entity entity) {
        id = entity.entityId;
        void write(ubyte[] data) {
            serialized ~= data;
        }
        auto writer = BinaryWriter(&write);
        entity.serializeBinary(writer);
    }

    void apply(WorldState world) {
        auto reader = BinaryMemoryReader(serialized);
        Entity entity = Entity.deserializeBinary(reader.reader);
        //auto  val = json.parse(serialized);
        //entity = Entity.deserialize(val);
    }

    ubyte[] toBytes() {
        ubyte[] tmp;
        tmp.length = id.sizeof + uint.sizeof + serialized.length;
        tmp[0..4] = (*cast(ubyte[4]*)&id)[];
        uint len = cast(uint) serialized.length;
        tmp[4..8] = (*cast(ubyte[4]*)&len)[];
        tmp[8..$] = (cast(ubyte[])serialized)[];
        return tmp;
    }
    size_t fromBytes(ubyte *ptr) {
        id = *cast(uint*)ptr;
        uint length = *cast(uint*)(ptr+4);
        serialized = ptr[8 .. length+8];
        return id.sizeof + length.sizeof + serialized.length;
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



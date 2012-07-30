module changes.worldproxy;

import std.traits;
import std.typetuple;

import unit;
import entities.entity;
import pos;
import worldstate.worldstate;
import worldstate.worldproxy;
import changes.changes;
import changes.changelist;
import clan;

import inventory;

string mixinChangeListAdd(string name, T)() {
    enum T_name = T.stringof;
    enum params = FieldTypeTuple!T.stringof;
        
    return "void "~name~"(TypeTuple!"~params~" ts) {"
        ~  "    changeList.add!"~T.stringof~"(ts);"
        ~  "}";
}

//pragma (msg, mixinChangeListAdd!("setTile", SetTile)());
//pragma (msg, FieldTypeTuple!SetTile.stringof);


mixin template mixinAllChangeListAdd(Ts...) {
    static if (Ts.length > 0) {
//        pragma(msg, mixinChangeListAdd!(Ts[0], Ts[1])());
        mixin(mixinChangeListAdd!(Ts[0], Ts[1])());
        mixin mixinAllChangeListAdd!(Ts[2 .. $]);
    }
}

final class WorldChangeListProxy : WorldProxy {
    WorldState world;
    ChangeList changeList;

    this(WorldState w) {
        world = w;
        changeList = new ChangeList;
    }

    WorldState unsafeGetWorld() {
        return world;
    }

    mixin mixinAllChangeListAdd!(
            "setTile", SetTile,
            "damageTile", DamageTile,
            "removeTile", RemoveTile,
            "createUnit", CreateUnit,
            "removeUnit", RemoveUnit,
            "moveUnit", MoveUnit,
            "setIntent", SetIntent,
            "setAction", SetAction,
            "createEntity", CreateEntity,
            "removeEntity", RemoveEntity,
            "moveEntity", MoveEntity,
            "activateEntity", ActivateEntity,
            "getMission", GetMission,
            "designateMine", DesignateMine,
            );

    void pickupEntity(Entity e, Unit u) {
        changeList.add!PickupEntity(e, u.inventory);
    }
    void depositEntity(Entity e, Unit u, Entity e2) {
        changeList.add!DepositEntity(e, u.inventory, e2.inventory);
    }

    void addCustomChange(CustomChange c) {
        changeList.addCustomChange(c);
    }

    Tile getTile(TilePos tp) {
        return world.getTile(tp);
    }

    void apply() {
        changeList.apply(world);
    }

}


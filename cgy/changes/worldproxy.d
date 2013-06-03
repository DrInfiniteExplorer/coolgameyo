module changes.worldproxy;

import std.traits;
import std.typetuple;

import changes.changes;
import changes.changelist;
import changes.worldproxy;
import clan;
import entities.entity;
import json;
import unit;
import util.pos;
import tiletypemanager;
import worldstate.worldstate;

import inventory;


string mixinChangeListAdd(string name, T)() {
    immutable T_name = T.stringof;
    static if( hasMember!(T, "__ctor")) {
        string str = "";
        alias typeof(__traits(getOverloads, T, "__ctor")) constructors;
        foreach(overload ; constructors){ 
            immutable params = ParameterTypeTuple!overload.stringof;
            str ~= " void "~name~"(TypeTuple!"~params~" ts) {"
                ~  "    changeList.add!"~T.stringof~"(ts);"
                ~  "}\n";
        }
        return str;
    } else {
        immutable params = FieldTypeTuple!T.stringof;
        return "void "~name~"(TypeTuple!"~params~" ts) {"
            ~  "    changeList.add!"~T.stringof~"(ts);"
            ~  "}";
    }
}
//pragma (msg, mixinChangeListAdd!("setTile", SetTile)());
//pragma (msg, FieldTypeTuple!SetTile.stringof);


mixin template mixinAllChangeListAdd(Ts...) {
    static if (Ts.length > 0) {
        //pragma(msg, mixinChangeListAdd!(Ts[0], Ts[1])());
        mixin(mixinChangeListAdd!(Ts[0], Ts[1])());
        mixin mixinAllChangeListAdd!(Ts[2 .. $]);
    }
}

final class WorldProxy {
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

    /*
    void pickupEntity(Entity e, Unit u) {
        changeList.add!PickupEntity(e, u.inventory);
    }
    void depositEntity(Entity e, Unit u, Entity e2) {
        changeList.add!DepositEntity(e, u.inventory, e2.inventory);
    }
    */

    /*
    void addCustomChange(CustomChange c) {
        changeList.addCustomChange(c);
    }
    */

    Tile getTile(TilePos tp) {
        return world.getTile(tp);
    }

    void apply() {
        changeList.apply(world);
    }

}



module changes.changelist;

import std.stdio;
import std.typetuple;

import unit;

import util.util;
import util.array;
import worldstate.worldstate;
import changes.changes;

alias util.array.Array Array;

final class ChangeList {

    alias TypeTuple!(
            SetTile,
            DamageTile,
            RemoveTile,

            CreateUnit,
            RemoveUnit,
            MoveUnit,

            SetIntent,
            SetAction,

            CreateEntity,
            RemoveEntity,
            MoveEntity,
            PickupEntity,
            DepositEntity,
            ActivateEntity,

            GetMission,
            DesignateMine,

            CustomChange
            ) ChangeTypes;

    ubyte[] changeListData;

    /*
    ref auto changes(T)() {
        return changeArrays.byType!T();
    }

    void add(T, Us...)(Us us) {
        changes!T().insert(T(us));
    }
    void addCustomChange(CustomChange c){
        changes!CustomChange().insert(c);
    }
    */

    this() {
    }

    void add(T)(ref T change) if(staticIndexOf!(T, ChangeTypes) != -1) {
        ubyte[] asBytes = (cast(ubyte*)&change)[0..T.sizeof];
        changeListData ~= cast(ubyte)staticIndexOf!(T, ChangeTypes) ~ asBytes;
    }
    void add(T, Us...)(Us us) if(!is(T : Us[0])){
        add!T(T(us));
    }

    void apply(WorldState world){
        ubyte* ptr = changeListData.ptr;
        ubyte* endPtr = ptr + changeListData.length;
        while(ptr !is endPtr) {
            ubyte type = *ptr;
            ptr++;
            switch(type) {
            foreach(idx, T ; ChangeTypes)   {
                case idx:
                    {
                        auto changePtr = cast(T*)ptr;
                        changePtr.apply(world);
                        ptr += (*changePtr).sizeof;
                    }
                    break;
                }
            }

        }
        reset();
    }

    void reset() {
        changeListData.length = 0;
        assumeSafeAppend(changeListData);
    }

    void readFrom(ubyte[] bytes) {
        changeListData ~= bytes;
    }
}


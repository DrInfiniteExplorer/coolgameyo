
module changes.changelist;

import std.stdio;
import std.typetuple;

import unit;

import util.util;
import util.array;
import world.world;
import changes.changes;

alias util.array.Array Array;

struct ChangeArrayCollection(Cs...) {
    staticMap!(Array, Cs) arrays;

    auto byType(T)() {
        return arrays[staticIndexOf!(T, Cs)];
    }
}


final class ChangeList {

    ChangeArrayCollection!(
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

            CustomChange
            ) changeArrays;

    auto changes(T)() {
        return changeArrays.byType!T();
    }

    void add(T, Us...)(Us us) {
        changes!T().insert(T(us));
    }
    void addCustomChange(CustomChange c){
        changes!CustomChange().insert(c);
    }

    this() {
    }
    
    void apply(World world){
    }
}


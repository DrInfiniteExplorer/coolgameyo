
module changes.changelist;

import std.stdio;
import std.typetuple;

import unit;

import util.util;
import util.array;
import worldstate.worldstate;
import changes.changes;

alias util.array.Array Array;

struct ChangeArrayCollection(Cs...) {
    staticMap!(Array, Cs) arrays;

    void init() {
        foreach (i, c; Cs) {
            arrays[i] = new typeof(arrays[i]);
        }
    }

    auto byType(T)() {
        return arrays[staticIndexOf!(T, Cs)];
    }

    void apply(WorldState world) {
        foreach (i, c; Cs) {
            foreach (w; arrays[i][]) {
                w.apply(world);
            }
        }
    }

    void reset() {
        foreach (i, c; Cs) {
            arrays[i].reset();
        }
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

            GetMission,
            DesignateMine,

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
        changeArrays.init();
    }
    
    void apply(WorldState world){
        changeArrays.apply(world);
        changeArrays.reset();
    }
}


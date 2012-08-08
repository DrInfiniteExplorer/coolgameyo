
module changes.changelist;

import std.stdio;

import unit;

import util.util;
import util.array;
import world.world;

// Only implemented by experimental or semi-hacky classes.
// List of such classes:
//  FPSControlAI
interface CustomChange {
    void apply(World world);
}

alias util.array.Array ChangeArray;


final class ChangeList {
    static struct MoveChange {
        Unit unit;
        vec3d destination;
        uint ticksToArrive;
    };
    ChangeArray!MoveChange moveChanges;
    ChangeArray!CustomChange customChanges;
    
    void addMovement(Unit unit, UnitPos destination, uint ticksToArrive) {
        addMovement(unit, destination.value, ticksToArrive);
    }
    void addMovement(Unit unit, vec3d destination, uint ticksToArrive) {
        moveChanges.insert(MoveChange(unit, destination, ticksToArrive));
    }
    void applyMovement(World world) {
        foreach(moveChange; moveChanges[]) {
            world.unsafeMoveUnit(moveChange.unit,
                    moveChange.destination, moveChange.ticksToArrive);
        }
    }
    
    this() {
        moveChanges = new ChangeArray!MoveChange;
        customChanges = new ChangeArray!CustomChange;
    }
    
    void addCustomChange(CustomChange change) {
        customChanges.insert(change);
    }
    
    void applyCustomChanges(World world) {
        foreach(change ; customChanges[]) {
            change.apply(world);
        }
    }

    void apply(World world){
        applyMovement(world);
        applyCustomChanges(world);

        moveChanges.reset();
        customChanges.reset();
    }
}


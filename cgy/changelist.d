
module changelist;

import std.stdio;

import unit;

import util.util;
import world.world;

// Only implemented by experimental or semi-hacky classes.
// List of such classes:
//  FPSControlAI
interface CustomChange {
    void apply(World world);
}

private struct ChangeArray(T) {
    T[] ts;

    size_t _length; // messy due to not can use length in []
    ref size_t length() @property { return _length; }

    void initialize() {
        ts.length = 1;
        ts.length = ts.capacity;
    }
    void insert(T t) {
        if (_length >= ts.length) {
            write("resizing ", typeid(this), " from ", ts.length);
            ts.length = (ts.length + 1) * 2 - 1; // 2^n-1 ---> 2^(n+1)-1
            writeln(" to ", ts.length);
            assert (ts.length == ts.capacity);
        }
        ts[_length] = t;
        _length += 1;
    }
    void reset() {
        // if (max length over last 10 ticks or whatever? < ts.length / 2) {
        //     ts = new T[](ts.length/2 - 1); // drop reference to old array
        // }
        _length = 0;
    }

    T[] active() @property { return ts[0 .. _length]; }
    T[] opSlice() { return active; }
    alias active this;
}

final class ChangeList {
    static struct MoveChange {
        Unit *unit;
        vec3d destination;
        uint ticksToArrive;
    };
    ChangeArray!MoveChange moveChanges;
    ChangeArray!CustomChange customChanges;
    
    void addMovement(Unit* unit, UnitPos destination, uint ticksToArrive) {
        addMovement(unit, destination.value, ticksToArrive);
    }
    void addMovement(Unit* unit, vec3d destination, uint ticksToArrive) {
        moveChanges.insert(MoveChange(unit, destination, ticksToArrive));
    }
    void applyMovement(World world) {
        foreach(moveChange; moveChanges[]) {
            world.unsafeMoveUnit(moveChange.unit,
                    moveChange.destination, moveChange.ticksToArrive);
        }
    }
    
    this() {
        moveChanges.initialize();
        customChanges.initialize();
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


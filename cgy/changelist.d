

module changelist;

import unit;
import util;
import world;

// Only implemented by experimental or semi-hacky classes.
// List of such classes:
//  FPSControlAI
interface CustomChange {
    void apply(World world);
}


final class ChangeList {
    static struct MoveChange {
        Unit *unit;
        vec3d destination;
        uint ticksToArrive;
    };
    MoveChange[] moveChanges;
    uint moveChangeCount;
    
    void addMovement(Unit *unit, vec3d destination, uint ticksToArrive) {
        moveChangeCount ++;
        //TODO: Implement shrinking, and usage of assumeSafeAppend() when growing
        if(moveChangeCount > moveChanges.length) {
            moveChanges.length = moveChangeCount;
        }
        MoveChange item;
        item.unit = unit;
        item.destination = destination;
        item.ticksToArrive = ticksToArrive;
        moveChanges[$-1] = item;
    }
    void applyMovement(World world){
        foreach(moveChange; moveChanges[0 .. moveChangeCount]) {
            world.unsafeMoveUnit(moveChange.unit, moveChange.destination, moveChange.ticksToArrive);
        }
        moveChangeCount = 0;
    }
    
    
    CustomChange[] customChanges;
    uint customChangeCount;
    void addCustomChange(CustomChange change) {
        customChangeCount ++;
        if(customChangeCount > customChanges.length) {
            customChanges.length = customChangeCount;
        }
        customChanges[$-1] = change;
    }
    
    void applyCustomChanges(World world) {
        foreach(change ; customChanges[0 .. customChangeCount]) {
            change.apply(world);
        }
    }

    void apply(World world){
        applyMovement(world);
        applyCustomChanges(world);
    }
    
}


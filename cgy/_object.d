
module _object;

import std.exception;
import std.stdio;

import json;
import changelist;
import pos;
import stolen.aabbox3d;
import util;
import world;
import clan;

shared int g_ObjectCount = 0; //Global counter of units. Make shared static variable in Game-class?

final class UnitType {
    string name;
    int x;
}

_Object* newObject() {
    auto _object = new _Object;
    _object.objectId = g_ObjectCount;
    g_ObjectCount++;
    return _object;
}

struct _Object {

    bool opEquals(ref const(_Object) o) const {
        assert (0, "Implement _Object.opEquals or find where it's called and make not called!");
    }

    uint objectId;
    UnitType type;

    Clan clan;
	
    ObjectPos pos;
    float rotation = 0; //radians

    float objectWidth = 0.7;
    float objectHeight = 1.5;
    
    Value serialize() {
        BREAKPOINT;
        return Value(1);
    }

    int tick(ChangeList changeList) {
        
        return 1;
    }

    //Returns the bounding box of the unit, in world space.
    //If no parameter is passed, the units position is used as base,
    //otherwise the passed position is padded with the unit-size.
    aabbox3d!(double) aabb(const(vec3d)* v = null) const @property {
        if(v is null){
            v = &pos.value;
        }
        auto minPos = (*v)  - vec3d(objectWidth * 0.5, objectWidth*0.5, 0);
        auto maxPos = minPos + vec3d(objectWidth, objectWidth, objectHeight);
        return aabbox3d!double(minPos, maxPos);
    }
}



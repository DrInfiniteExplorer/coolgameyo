
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

final class ObjectType {
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

    struct ObjectData {
        uint objectId;
        ObjectPos pos;
        float rotation = 0; //radians

        float objectWidth = 0.7;
        float objectHeight = 1.5;        
    }
    ObjectData objectData;
    alias objectData this;

    ObjectType type;
    Clan clan;
    
    Value toJSON() {
        Value val = encode(objectData);
        if (clan !is null) {
            val["clanId"] = Value(clan.clanId);
        }
        if (type !is null) {
            val["unitTypeId"] = Value(type.name);
        }
        //Add ai
        return val;
    }
    void fromJSON(Value val) {
        read(objectData, val);
        if ("clanId" in val) {
            int clanId;
            read(clanId, val["clanId"]);
            BREAKPOINT;
        }
        if ("unitTypeId" in val) {
            int unitTypeId;
            read(unitTypeId, val["unitTypeId"]);
            BREAKPOINT;
        }
        //Add ai
    }
        
	

    int tick(ChangeList changeList) {
        
        return 1;
    }

    //Returns the bounding box of the unit, in world space.
    //If no parameter is passed, the units position is used as base,
    //otherwise the passed position is padded with the unit-size.
    aabbox3d!(double) aabb(const(vec3d)* v = null) const @property {
        if(v is null){
            v = &objectData.pos.value;
        }
        auto minPos = (*v)  - vec3d(objectData.objectWidth * 0.5, objectData.objectWidth*0.5, 0);
        auto maxPos = minPos + vec3d(objectData.objectWidth, objectData.objectWidth, objectData.objectHeight);
        return aabbox3d!double(minPos, maxPos);
    }
}



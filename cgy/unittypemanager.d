import std.exception;
import std.algorithm;
import std.conv;
import std.stdio;
import std.file;

import graphics.texture;

import json;
import util.util;
import worldparts.tile;
import statistics;


struct UnitType {
	static struct InnerUnitType {
		string displayName;
		vec3i tintColor;
	}
	
	InnerUnitType serializableSettings;
    alias serializableSettings this;

	// These settings are generated in the program, not from settings file
	string name;
    ushort id;
}


class UnitTypeManager {
    UnitType[] types;
    ushort[string] _byName;
	
    invariant() {
        assert (types.length == _byName.length);
        assert (types.length < ushort.max);
    }
	
    this() {
        mixin(LogTime!("UnitTypeManagerCreation"));
		
		
		UnitType tempType;
		if(!std.file.exists("data/unit_types.json")){
			msg("Could not load unit types");
			return;
		}
		auto content = readText("data/unit_types.json");
		auto rootVal = json.parse(content);
		enforce(rootVal.type == json.Value.Type.object, "rootval in unittypejson not object roawoaowoawo: " ~ to!string(rootVal.type));
		foreach(name, rsVal ; rootVal.pairs) {
			json.read(tempType.serializableSettings, rsVal);
			
			tempType.name = name;
			add(tempType);
		}
    }

    UnitType byID(ushort id) {
        return types[id];
    }
    UnitType byName(string name) {
        return types[idByName(name)];
    }
    ushort idByName(string name) {
        return *enforce(name in _byName, "no unit type by name '" ~ name ~ "'");
    }

    ushort add(UnitType t) {
        enforce(!(t.name in _byName));
		
        t.id = to!ushort(types.length);
		
        types ~= t;
        _byName[t.name] = t.id;
		
        return t.id;
    }
}




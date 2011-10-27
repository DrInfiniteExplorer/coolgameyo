module entitytypemanager;

import std.exception;
import std.algorithm;
import std.conv;
import std.stdio;
import std.file;

import graphics.texture;

import json;

import worldparts.tile;
import statistics;
import util.util;


struct EntityType {
	static struct InnerEntityType {
		string displayName;
		float tintFromMaterial;
		vec3i tintColor;
		bool droppable;
		bool placeable;
	}
	
	InnerEntityType serializableSettings;
    alias serializableSettings this;

	// These settings are generated in the program, not from settings file
	string name;
    ushort id;
}


class EntityTypeManager {
    EntityType[] types;
    ushort[string] _byName;
	
    invariant() {
        assert (types.length == _byName.length);
        assert (types.length < ushort.max);
    }
	
    this() {
        mixin(LogTime!("EntityTypeManagerCreation"));
		
		
		EntityType tempType;
		if(!std.file.exists("data/entity_types.json")){
			msg("Could not load entity types");
			return;
		}
		auto content = readText("data/entity_types.json");
		auto rootVal = json.parse(content);
		enforce(rootVal.type == json.Value.Type.object, "rootval in entitytypejson not object roawoaowoawo: " ~ to!string(rootVal.type));
		foreach(name, rsVal ; rootVal.pairs) {
			json.read(tempType.serializableSettings, rsVal);
			
			tempType.name = name;
			add(tempType);
		}
    }

    EntityType byID(ushort id) {
        return types[id];
    }
    EntityType byName(string name) {
        return types[idByName(name)];
    }
    ushort idByName(string name) {
        return *enforce(name in _byName, "no entity type by name '" ~ name ~ "'");
    }

    ushort add(EntityType t) {
        enforce(!(t.name in _byName));
		
        t.id = to!ushort(types.length);
		
        types ~= t;
        _byName[t.name] = t.id;
		
        return t.id;
    }
}




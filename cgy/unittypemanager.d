import std.exception;
import std.algorithm;
import std.conv;
import std.stdio;
import std.file;

import graphics.texture;

import json;
import globals : g_worldPath;
import statistics;
import util.singleton; 
import util.util;
import worldstate.tile;

struct UnitModelInfo {
    string name;
    string[] meshTextures;
    string skeletonName;//Skeleton family
}

struct UnitType_t {
	static struct InnerUnitType {
		string displayName;
		vec3i tintColor;
        UnitModelInfo model;   //Model family
	}
	
	InnerUnitType serializableSettings;
    alias serializableSettings this;

	// These settings are generated in the program, not from settings file
	string name;
    ushort id;
}
alias UnitType_t* UnitType;


class UnitTypeManager {
    UnitType_t[] types;
    ushort[string] _byName;
	
    invariant() {
        //assert (types.length == _byName.length); // because of id definition file, types.length can be bigger than _byName.length
        assert (types.length < ushort.max);
    }

    mixin Singleton!();
	
    private this() {
    }

    void init() {
        mixin(LogTime!("UnitTypeManagerCreation"));
		
        // Loads the unit type id configuration
        Value idRootVal;
        bool hasTypeIdConfFile = loadJSON(g_worldPath ~ "/unittypeidconfiguration.json", idRootVal);
		
		if(!std.file.exists("data/unit_types.json")){
			msg("Could not load unit types");
			return;
		}
		auto content = readText("data/unit_types.json");
		auto rootVal = json.parse(content);
		enforce(rootVal.type == json.Value.Type.object, "rootval in unittypejson not object roawoaowoawo: " ~ to!string(rootVal.type));
		foreach(name, rsVal ; rootVal.asObject) {
            UnitType_t tempType;
			rsVal.read(tempType.serializableSettings);
			
			tempType.name = name;
            if ( hasTypeIdConfFile == true && tempType.name in idRootVal) {
                ushort id;
                idRootVal[tempType.name].read(id);
			    add(tempType, id, true);
            }
            else {
                add(tempType);
            }
		}

        /*
        // This should be done with some fancy json function...
        // Saves the unit type id configuration
        string jsonString = "{\n";
        for (int i = 0; i < types.length; i++) {
            jsonString ~= "\"";
            jsonString ~= types[i].name;
            jsonString ~= "\":";
            jsonString ~= to!string(types[i].id);
            jsonString ~= ",\n";
        }
        jsonString~="}";
        util.filesystem.mkdir(g_worldPath ~ "");
        std.file.write(g_worldPath ~ "/unittypeidconfiguration.json", jsonString);
        */
        util.filesystem.mkdir(g_worldPath ~ "");
        ushort[string] typeAA;
        foreach(type ; types) {
            typeAA[type.name] = type.id;
        }
        encode(typeAA).saveJSON(g_worldPath ~ "/unittypeidconfiguration.json");
    }

    UnitType byID(ushort id) {
        return &types[id];
    }
    UnitType byName(string name) {
        return &types[idByName(name)];
    }
    ushort idByName(string name) {
        return *enforce(name in _byName, "no unit type by name '" ~ name ~ "'");
    }

    // Adds unit to the unit list. If we want to we can force an id.
    //Only ever add a unit type when loading a game; Otherwise type pointers
    //can be made to point to the wrong type!
    ushort add(UnitType_t unit, ushort id = 0, bool isSendingId = false) {
        enforce(!(unit.name in _byName));

        // This is ok since we can't have a unit with id 0
        if (isSendingId) {
            unit.id = id;
            if (unit.id >= types.length) {
                types.length = unit.id+1;
            }
            // If the forced id spot is occupied, rearrange types[]
            if (types[unit.id].id != 0) {
                auto intrudingBastard = types[unit.id];
                ushort newPlace = 0;
                for (ushort i = 1; i < types.length; i++) {
                    if (types[i].id == 0) {
                        newPlace = i;
                        break;
                    }
                }
                if (newPlace != 0) {
                    intrudingBastard.id = newPlace;
                }
                else {
                    intrudingBastard.id = to!ushort(types.length);
                    types ~= intrudingBastard;
                }
                _byName[intrudingBastard.name] = intrudingBastard.id;
                types[intrudingBastard.id] = intrudingBastard;
            }
            types[unit.id] = unit;
		}
        else {
            unit.id = to!ushort(types.length);
            types ~= unit;
        }

        _byName[unit.name] = unit.id;

        return unit.id;
    }
}




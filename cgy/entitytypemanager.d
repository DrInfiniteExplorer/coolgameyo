module entitytypemanager;

import std.exception;
import std.algorithm;
import std.conv;
import std.stdio;
import std.file;

import graphics.texture;

import json;

import world.tile;
import statistics;
import util.util;

struct EntityModelInfo {
    string name;
    string[] meshTextures;
    string skeletonName;//Skeleton family
}


struct EntityType {
	static struct InnerEntityType {
		string displayName;
		float tintFromMaterial;
		vec3i tintColor;
		bool droppable;
		bool placeable;
        ubyte lightStrength = 0;
        vec3d lightTintColor;

        EntityModelInfo model;   //Model family
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
        //assert (types.length == _byName.length); // because of id definition file, types.length can be bigger than _byName.length
        assert (types.length < ushort.max);
    }
	
    this() {
        mixin(LogTime!("EntityTypeManagerCreation"));
		
        // Loads the entity type id configuration
        Value idRootVal;
        bool hasTypeIdConfFile = loadJSONFile("saves/current/entitytypeidconfiguration.json", &idRootVal);

		//EntityType tempType;
		if(!std.file.exists("data/entity_types.json")){
			msg("Could not load entity types");
			return;
		}
		auto content = readText("data/entity_types.json");
		auto rootVal = json.parse(content);
		enforce(rootVal.type == json.Value.Type.object, "rootval in entitytypejson not object roawoaowoawo: " ~ to!string(rootVal.type));
		foreach(name, rsVal ; rootVal.pairs) {
            EntityType tempType; // is is le working if this is here lololooo.
            // problem is tree gets light, shrubbery dont. neither should.
            // build expansion then defense it
			json.read(tempType.serializableSettings, rsVal);
			
			tempType.name = name;
            if ( hasTypeIdConfFile == true && tempType.name in idRootVal) {
                ushort id;
                read(id, idRootVal[tempType.name]);
			    add(tempType, id, true);
            }
            else {
                add(tempType);
            }
		}

        // This should be done with some fancy json function...
        // Saves the entity type id configuration
        string jsonString = "{\n";
        for (int i = 0; i < types.length; i++) {
            jsonString ~= "\"";
            jsonString ~= types[i].name;
            jsonString ~= "\":";
            jsonString ~= to!string(types[i].id);
            jsonString ~= ",\n";
        }
        jsonString~="}";
        util.filesystem.mkdir("saves/current");
        std.file.write("saves/current/entitytypeidconfiguration.json", jsonString);
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

    // Adds entity to the entity list. If we want to we can force an id.
    ushort add(EntityType entity, ushort id = 0, bool isSendingId = false) {
        enforce(!(entity.name in _byName));

        if (isSendingId) {
            entity.id = id;
            if (entity.id >= types.length) {
                types.length = entity.id+1;
            }
            // If the forced id spot is occupied, rearrange types[]
            if (types[entity.id].id != 0) {
                auto intrudingBastard = types[entity.id];
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
            types[entity.id] = entity;
		}
        else {
            entity.id = to!ushort(types.length);
            types ~= entity;
        }

        _byName[entity.name] = entity.id;

        return entity.id;
    }
}




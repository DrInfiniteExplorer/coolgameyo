module entitytypemanager;

import std.exception;
import std.algorithm;
import std.conv;
import std.stdio;
import std.file;

import graphics.texture;

import json;

import worldstate.tile;
import statistics;
import util.util;

struct BranchType {
    ubyte id;                           // id=0 is reserved for the start branch which is NOT defined in a file. See this as the seeds or the entity.
    ubyte growsOn;                      // this refers to an id of a different branch type
    float spawnChance;                  // spawnChance is for this branch. If multiple branch types can grow on the same branch type, all types will have chance to spawn.
    ubyte nrOfNodesTarget;
    ubyte nrOfNodesTargetVariation;
    float newNodeChance;
    float newNodePos;
    float newNodePosDistanceCost;
    float newNodePosRandomness;
    ubyte nodeDistanceTarget;
    ubyte nodeDistanceTargetVariation;
    float nodeDistanceIncreaseChace;

    float angleFromParent;              // Measured in radians
    float angleFromParentVariation;
    float nodeFirstDeriveAngle;
    float nodeSecondDeriveAngle;
    float posOnParent;                  // 0.0 = first node on parent branch, 1.0 = newest node on parent branch
    ubyte posOnParentMin;               // the branch can only spawn on a node with index higher than this
    float posOnParentDistanceCost;      // how much the chance to spawn this branch is affected by distance from posOnParent
    float posOnParentCrowdedCost;       // how much the cost is increased for each other branch on the parent node
    float posOnParentRandomness;        // random[0, posOnParentRandomness] is added to each node when choosing best node

    float thicknessStart;
    float thicknessTarget;
    float thicknessTargetVariation;
    float thicknessDistanceCost;
    float thicknessGrowth;

    float leafDensity;
    float leafRadius;
    float gravityAffection;
    ubyte branchesPerBranchTarget;
    ubyte branchesPerBranchTargetVariation;

    bool pineShape;
}
struct TreelikeType {
    string woodMaterial; // flytta till branches
	string leafMaterial;
    BranchType[] branches;
}
struct EntityModelInfo {
    string name;
    string[] meshTextures;
    string skeletonName;//Skeleton family
}


struct EntityType_t {
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

    TreelikeType treelike;
	
	InnerEntityType serializableSettings;
    alias serializableSettings this;

	// These settings are generated in the program, not from settings file
	string name;
    ushort id;
}
alias EntityType_t* EntityType;


class EntityTypeManager {
    EntityType_t[] types;
    ushort[string] _byName;
	
    invariant() {
        //assert (types.length == _byName.length); // because of id definition file, types.length can be bigger than _byName.length
        assert (types.length < ushort.max);
    }
	
    this() {
        mixin(LogTime!("EntityTypeManagerCreation"));
		
        // Loads the entity type id configuration
        Value idRootVal;
        bool hasTypeIdConfFile = loadJSON("saves/current/entitytypeidconfiguration.json", idRootVal);

		//EntityType tempType;
		if(!std.file.exists("data/entity_types.json")){
			msg("Could not load entity types");
			return;
		}
		auto content = readText("data/entity_types.json");
		auto rootVal = json.parse(content);
		enforce(rootVal.type == json.Value.Type.object, "rootval in entitytypejson not object roawoaowoawo: " ~ to!string(rootVal.type));
		foreach(name, rsVal ; rootVal.pairs) {
            EntityType_t tempType; // is is le working if this is here lololooo.
            // problem is tree gets light, shrubbery dont. neither should.
            // build expansion then defense it
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
        */
        util.filesystem.mkdir("saves/current");
        ushort[string] typeAA;
        foreach(type ; types) {
            typeAA[type.name] = type.id;
        }
        encode(typeAA).saveJSON("saves/current/entitytypeidconfiguration.json");

    }

    EntityType byID(ushort id) {
        return &types[id];
    }
    EntityType byName(string name) {
        return &types[idByName(name)];
    }
    ushort idByName(string name) {
        if(!(name in _byName)) {
            BREAKPOINT; //If breaks here, step out and find out where it came from.
            return 0;
        }
        return *enforce(name in _byName, "no entity type by name '" ~ name ~ "'");
    }

    // Adds entity to the entity list. If we want to we can force an id.
    ushort add(EntityType_t entity, ushort id = 0, bool isSendingId = false) {
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




module tiletypemanager;

import std.exception;
import std.algorithm;
import std.array;
import std.conv;
import std.stdio;
import std.file;

import graphics.texture;

import json;

import statistics;
import util.util;
import world.tile;

//ALWAYS!!
enum TileTypeInvalid = 0;
enum TileTypeAir = 1;

static struct TileTextureID {
    ushort top, side, bottom;
}

struct TileType_t {
	static struct InnerTileType {
		string displayName;
		string material;
		int strength;
		float tintFromMaterial;
		vec3i tintColor;
		string texturePathTop;
		string texturePathSides;
		string texturePathBottom;
		vec2i textureCoordTop;
		vec2i textureCoordSides;
		vec2i textureCoordBottom;
	}
	
	InnerTileType serializableSettings;
    alias serializableSettings this;

	// These settings are generated in the program, not from settings file
    TileTextureID textures;
	string name;
    ushort id = 0;
    bool transparent = false;
}
alias TileType_t* TileType;


class TileTypeManager {
    TileType[] types;
    ushort[string] _byName;

    invariant() {
        //assert (types.length == _byName.length); // because of id definition file, types.length can be bigger than _byName.length
        assert (types.length < ushort.max);
    }

    this(TileTextureAtlas atlas) {
        mixin(LogTime!("TileTypeManagerCreation"));

		TileType invalid;
        TileType air;
        air.name = "air";
        air.transparent = true;
        add(invalid);
        add(air);
		atlas.addTile("textures/001.png", vec2i(0, 0)); // Invalid tile texture
		
        // Loads the tile type id configuration
        Value idRootVal;
        bool hasTypeIdConfFile = loadJSON("saves/current/tiletypeidconfiguration.json", idRootVal);

		TileType tempType;
		if(!std.file.exists("data/tile_types.json")){
			msg("Could not load tile types");
			return;
		}
		auto content = readText("data/tile_types.json");
		auto rootVal = json.parse(content);
		enforce(rootVal.type == json.Value.Type.object, "rootval in tiltypejson not object roawoaowoawo: " ~ to!string(rootVal.type));
		foreach(name, rsVal ; rootVal.pairs) {
			rsVal.read(tempType.serializableSettings);
			tempType.textures.top = atlas.addTile(
					tempType.texturePathTop,
                    tempType.textureCoordTop,
					tempType.tintColor);
			tempType.textures.side = atlas.addTile(
					tempType.texturePathSides,
                    tempType.textureCoordSides,
					tempType.tintColor);
            tempType.textures.bottom = atlas.addTile(
					tempType.texturePathBottom,
                    tempType.textureCoordBottom,
					tempType.tintColor);
			
			tempType.name = name;
            if ( hasTypeIdConfFile == true && tempType.name in idRootVal) {
                ushort id;
                idRootVal[tempType.name].read(id);
                enforce(id > 1, "Some tile type wants to hijack the invalid or air tile type");
			    add(tempType, id, true);
            }
            else {
                add(tempType);
            }
		}

        /*
        // This should be done with some fancy json function...
        // Saves the tile type id configuration
        string jsonString = "{\n";
        for (int i = 0; i < types.length; i++) {
            if (types[i].id > 1) {
                jsonString ~= "\"";
                jsonString ~= types[i].name;
                jsonString ~= "\":";
                jsonString ~= to!string(types[i].id);
                jsonString ~= ",\n";
            }
        }
        jsonString~="}";
        util.filesystem.mkdir("saves/current");
        std.file.write("saves/current/tiletypeidconfiguration.json", jsonString);
        */

        util.filesystem.mkdir("saves/current");
        // don't save invalid or air
        ushort[string] typeAA;
        foreach(type ; types) {
            if(type.id > 1) {
                typeAA[type.name] = type.id;
            }
        }
        encode(typeAA).saveJSON("saves/current/tiletypeidconfiguration.json");

    }

    TileType byID(ushort id) {
        return types[id];
    }
    TileType byName(string name) {
        return types[idByName(name)];
    }
    ushort idByName(string name) {
        return *enforce(name in _byName, "no tile type by name '" ~ name ~ "'");
    }

    // Adds tile to the tile list. If we want to we can force an id.
    ushort add(TileType tile, ushort id = 0, bool isSendingId = false) {
        enforce(!(tile.name in _byName));
		
        if (isSendingId) {
            tile.id = id;
            if (tile.id >= types.length) {
                types.length = tile.id+1;
            }
            // If the forced id spot is occupied, rearrange types[]
            if (types[tile.id].id != 0) {
                auto intrudingBastard = types[tile.id];
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
            types[tile.id] = tile;
		}
        else {
            tile.id = to!ushort(types.length);
            types ~= tile;
        }
        
        _byName[tile.name] = tile.id;
		
        return tile.id;
    }
}




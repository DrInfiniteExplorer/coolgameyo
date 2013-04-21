module tiletypemanager;

import std.exception;
import std.algorithm;
import std.array;
import std.conv;
import std.stdio;
import std.string;

import graphics.texture;

import json;
import globals : g_worldPath;
import materials;

import statistics;
import util.filesystem;
import util.util;
import worldstate.tile;

//ALWAYS!!
immutable TileTypeInvalid = 0;
immutable TileTypeAir = 1;

static struct TileTextureID {
    ushort top, side, bottom;
}

struct TileType_t {
	static struct InnerTileType {
		string displayName;
		string material;
        //string group; // Not needededed.
		int strength;
		float tintFromMaterial; // Hurr durr used is supposed to how?
		vec3ub tintColor;
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
    TileTextureAtlas atlas;
    TileType_t[] types;
    ushort[string] _byName;

    TileType[][string] tileTypeGroups;

    invariant() {
        //assert (types.length == _byName.length); // because of id definition file, types.length can be bigger than _byName.length
        assert (types.length < ushort.max);
    }

    this(TileTextureAtlas _atlas) {
        atlas = _atlas;
        mixin(LogTime!("TileTypeManagerCreation"));

		TileType_t invalid;
        TileType_t air;
        air.name = "air";
        air.transparent = true;
        add(invalid);
        add(air);
        if(atlas !is null) {
    		atlas.addTile("textures/001.png", vec2i(0, 0)); // Invalid tile texture
        }
		
        // Loads the tile type id configuration
        Value idRootVal;
        bool hasTypeIdConfFile = loadJSON(g_worldPath ~ "/tiletypeidconfiguration.json", idRootVal);

		TileType_t tempType;
		if(!exists("data/tile_types.json")){
			msg("Could not load tile types");
			return;
		}
		auto content = readText("data/tile_types.json");
		auto rootVal = json.parse(content);
		enforce(rootVal.type == json.Value.Type.object, "rootval in tiltypejson not object roawoaowoawo: " ~ to!string(rootVal.type));
		foreach(name, rsVal ; rootVal.pairs) {
			rsVal.read(tempType.serializableSettings);
			
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

        util.filesystem.mkdir(g_worldPath ~ "");
        // don't save invalid or air
        ushort[string] typeAA;
        foreach(type ; types) {
            if(type.id > 1) {
                typeAA[type.name] = type.id;
            }
        }
        encode(typeAA).saveJSON(g_worldPath ~ "/tiletypeidconfiguration.json");

        foreach(groupName, val ; loadJSON("data/tile_groups.json").asObject()) {
            TileType[] group;
            foreach(idx, typeName ; val.asArray()) {
                group ~= byName(typeName.str());
            }
            tileTypeGroups[groupName] = group;
        }

    }

    TileType byID(ushort id) {
        return &types[id];
    }
    TileType byName(string name) {
        return &types[idByName(name)];
    }
    ushort idByName(string name) {
        return *enforce(name in _byName, "no tile type by name '" ~ name ~ "'");
    }

    TileType[] getGroup(string groupName) {
        BREAK_IF(! (groupName in tileTypeGroups));
        enforce(groupName in tileTypeGroups, "Cant find group for group-name:" ~ groupName);
        return tileTypeGroups[groupName];
    }


    void loadTextures(ref TileType_t type) {
        BREAK_IF(type.textures.top || type.textures.side || type.textures.bottom);
        if(type.texturePathTop is null) return; // MIGHT BE AIR OR INVALID OMG!
        if(atlas) {
            type.textures.top = atlas.addTile(
                                              type.texturePathTop,
                                              type.textureCoordTop,
                                              type.tintColor);
            type.textures.side = atlas.addTile(
                                               type.texturePathSides,
                                               type.textureCoordSides,
                                               type.tintColor);
            type.textures.bottom = atlas.addTile(
                                                 type.texturePathBottom,
                                                 type.textureCoordBottom,
                                                 type.tintColor);
        }
    }

    // Adds tile to the tile list. If we want to we can force an id.
    ushort add(TileType_t tile, ushort id = 0, bool isSendingId = false) {
        enforce(!(tile.name in _byName));

        loadTextures(tile);
		
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

    void generateMaterials() {
        foreach(material ; g_materials) {
            auto name = material.name;
            if(name in _byName) continue;
            auto group = name in tileTypeGroups;
            if(group) continue; // Seems unlikely.. maybe manually defined by someone later.
            // NOT LOADED WE MUST CREATE IT BY OURSELVES
            auto type = material.type;
            auto groupName = "generic" ~ toUpper(type[0..1]) ~ type[1 .. $];
            auto typeGroup = getGroup(groupName);
            BREAK_IF(!typeGroup);
            // Create tiles for this group hurr hurr! and also create the group for this derpherp!
            TileType[] newGroup;
            TileType_t tmpType;
            char c = 'a';
            foreach(origTile ; typeGroup) {
                tmpType = *origTile;
                tmpType.name = name ~ "_" ~ c; // Hurr durr durr.
                tmpType.displayName = name;
                tmpType.material = name;
                tmpType.strength = material.tileStrength;
                tmpType.tintColor = material.color;
                tmpType.textures = TileTextureID.init;
                tmpType.id = 0;
                c++;
                
                auto id = add(tmpType);
                newGroup ~= byID(id);
            }
            tileTypeGroups[name] = newGroup;
        }
    }
}




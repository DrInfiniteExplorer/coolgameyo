import std.exception;
import std.algorithm;
import std.conv;
import std.stdio;
import std.file;

import graphics.texture;

import json;
import util;
import worldparts.tile;

//ALWAYS!!
enum TileTypeInvalid = 0;
enum TileTypeAir = 1;

static struct TileTextureID {
    ushort top, side, bottom;
}

struct TileType {
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
    ushort id;
    bool transparent = false;
}


class TileTypeManager {
    TileType[] types;
    ushort[string] _byName;

    invariant() {
        assert (types.length == _byName.length);
        assert (types.length < ushort.max);
    }

    this(TileTextureAtlas atlas) {
		TileType invalid;
        TileType air;
        air.name = "air";
        air.transparent = true;
        add(invalid);
        add(air);
		atlas.addTile("textures/001.png", vec2i(0, 0)); // Invalid tile texture
		
		TileType tempType;
		if(!std.file.exists("data/tile_types.json")){
			writeln("Could not load tile types");
			return;
		}
		auto content = readText("data/tile_types.json");
		auto rootVal = json.parse(content);
		enforce(rootVal.type == json.Value.Type.object, "rootval in tiltypejson not object roawoaowoawo: " ~ to!string(rootVal.type));
		foreach(name, rsVal ; rootVal.pairs) {
			json.update(&tempType.serializableSettings, rsVal);
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
			add(tempType);
		}
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

    ushort add(TileType t) {
        enforce(!(t.name in _byName));
		
        t.id = to!ushort(types.length);
		
        types ~= t;
        _byName[t.name] = t.id;
		
        return t.id;
    }
}




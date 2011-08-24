import std.exception;
import std.algorithm;
import std.conv;
import std.stdio;
import std.file;

import graphics.texture;

import json;
import util;
import worldparts.tile;
import statistics;

static struct TileTextureID {
    ushort top, side, bottom;
}

struct EntityType {
	static struct InnerEntityType {
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
	
	InnerEntityType serializableSettings;
    alias serializableSettings this;

	// These settings are generated in the program, not from settings file
    TileTextureID textures;
	string name;
    ushort id;
    bool transparent = false;
}


class EntityTypeManager {
    EntityType[] types;
    ushort[string] _byName;

    invariant() {
        assert (types.length == _byName.length);
        assert (types.length < ushort.max);
    }

    this(TileTextureAtlas atlas) {
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

    EntityType byID(ushort id) {
        return types[id];
    }
    EntityType byName(string name) {
        return types[idByName(name)];
    }
    ushort idByName(string name) {
        return *enforce(name in _byName, "no tile type by name '" ~ name ~ "'");
    }

    ushort add(EntityType t) {
        enforce(!(t.name in _byName));
		
        t.id = to!ushort(types.length);
		
        types ~= t;
        _byName[t.name] = t.id;
		
        return t.id;
    }
}




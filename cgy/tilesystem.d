import std.exception;
import std.algorithm;
import std.conv;

import worldparts.tile;

static struct TileTextureID {
    ushort top, side, bottom;
}

class TileType {
    TileTextureID textures;

    ushort id;

    bool transparent = false;
    string name = "invalid";

    this() {}
}


class TileSystem {
    TileType[] types;
    ushort[string] _byName;

    invariant() {
        assert (types.length == _byName.length);
        assert (types.length < ushort.max);
    }

    this() {
        TileType invalid = new TileType;
        TileType air = new TileType;

        air.name = "air";
        air.transparent = true;

        add(invalid);
        add(air);
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




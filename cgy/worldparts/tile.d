
module worldparts.tile;

import std.bitmanip;

import light;
import tiletypemanager : TileTypeAir;
import util.util;


//TODO: Make things private?


enum TileFlags : ushort {
    none        = 0,
    seen        = 1 << 0,
    pathable    = 1 << 4,
    valid       = 1 << 15,
}

struct Tile {
    ushort type;
    TileFlags flags = TileFlags.none;

    this(ushort type, TileFlags flags) {
        this.type = type;
        this.flags = flags;
        lightValue = 0;
        hitpoints = 0;
        restofderpystuff = 0;
    }

    static assert(2^^4 == MaxLightStrength);

    mixin(bitfields!(
        ubyte, "lightVal",           4,
        uint, "hitpoints",          12,
        uint, "restofderpystuff",   16 ));


    byte lightValue() const @property { return lightVal; }
    void lightValue(const byte light) @property { lightVal = clamp!byte(light, 0, 15); } //Do clamp in byte-domain to fix values like -1 etc

    bool valid() const @property { return (flags & TileFlags.valid) != 0; }
    void valid(bool val) @property { setFlag(flags, TileFlags.valid, val); }

    bool seen() const @property { return (flags & TileFlags.seen) != 0; }
    void seen(bool val) @property { setFlag(flags, TileFlags.seen, val); }

    bool isAir() const @property { return type == TileTypeAir; }

    bool pathable() const @property { return (flags & TileFlags.pathable) != 0; }
    void pathable(bool val) @property { setFlag(flags, TileFlags.pathable, val); }
}

enum INVALID_TILE = Tile(0, TileFlags.none);


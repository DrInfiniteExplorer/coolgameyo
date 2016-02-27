
module worldstate.tile;

import std.algorithm.comparison : clamp;
import std.bitmanip;
import std.conv;

import light;
import cgy.math.math;
import tiletypemanager : TileTypeAir, TileType;
import cgy.util.util;


//TODO: Make things private?


enum TileFlags : ushort {
    none        = 0,
    pathable    = 1 << 4,
    valid       = 1 << 15,
}

struct Tile {

    this(TileType type, TileFlags flags) {
        this(type.id, flags, type.strength);
    }
    this(ushort type, TileFlags flags, int strength) {
        this.type = type;
        this.flags = flags;
        lightValue = 0;
        hitpoints = cast(ubyte)strength;
        restofderpystuff = 0;
    }

    static assert(2^^4 -1== MaxLightStrength);

    ushort type;                            // 2 bytes
    TileFlags flags = TileFlags.none;       // 2 bytes
    ubyte hitpoints;                        // 1 bytes
    ubyte derppoints;                       // 1 bytes
    mixin(bitfields!(                       // 2 bytes
        ubyte, "lightVal",           4,
        ubyte, "sunLightVal",        4,
        uint, "restofderpystuff",    8 ));


    ubyte lightValue() const @property { return lightVal; }
    void lightValue(const ubyte light) @property { lightVal = cast(ubyte)clamp(light, 0, 15); } //Do clamp in byte-domain to fix values like -1 etc

    ubyte sunLightValue() const @property { return sunLightVal; }
    void sunLightValue(const ubyte light) @property { sunLightVal = cast(ubyte)clamp(light, 0, 15); } //Do clamp in byte-domain to fix values like -1 etc

    void setLight(bool sunLight, const byte light) {
        if(sunLight) {
            sunLightValue = light;
        } else {
            lightValue = light;
        }
    }
    byte getLight(bool sunLight) const {
        return (sunLight ? sunLightValue : lightValue);
    }

    bool valid() const @property { return (flags & TileFlags.valid) != 0; }
    void valid(bool val) @property { setFlag(flags, TileFlags.valid, val); }

    bool sunlight() const @property { return sunLightValue == MaxLightStrength; }

    bool isAir() const @property { return type == TileTypeAir; }

    bool pathable() const @property { return (flags & TileFlags.pathable) != 0; }
    void pathable(bool val) @property { setFlag(flags, TileFlags.pathable, val); }

    string describe() const {
        return "";
        /*
        string ret = "";
        ret ~= pathable ? "Pathable, " : "Unpathable, ";
        ret ~= valid ? "Valid, " : "Invalid, ";
        ret ~= to!string(lightValue) ~ "," ~to!string(sunLightValue) ~ ",";
        return ret;
        */
    }
}

immutable airTile = Tile(TileTypeAir, TileFlags.valid, 0);
immutable INVALID_TILE = Tile(0, TileFlags.none, 0);


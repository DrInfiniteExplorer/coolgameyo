
module worldstate.tile;

import std.bitmanip;
import std.conv;

import light;
import tiletypemanager : TileTypeAir;
import util.util;
import util.math;


//TODO: Make things private?


enum TileFlags : ushort {
    none        = 0,
    pathable    = 1 << 4,
    valid       = 1 << 15,
}

immutable airTile = Tile(TileTypeAir, TileFlags.valid);

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

    static assert(2^^4 -1== MaxLightStrength);

    ubyte hitpoints;
    ubyte derppoints;
    mixin(bitfields!(
        ubyte, "lightVal",           4,
        ubyte, "sunLightVal",        4,
        uint, "restofderpystuff",    8 ));


    byte lightValue() const @property { return lightVal; }
    void lightValue(const byte light) @property { lightVal = clamp!byte(light, 0, 15); } //Do clamp in byte-domain to fix values like -1 etc

    byte sunLightValue() const @property { return sunLightVal; }
    void sunLightValue(const byte light) @property { sunLightVal = clamp!byte(light, 0, 15); } //Do clamp in byte-domain to fix values like -1 etc

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
        string ret = "";
        ret ~= pathable ? "Pathable, " : "Unpathable, ";
        ret ~= valid ? "Valid, " : "Invalid, ";
        ret ~= to!string(lightValue) ~ "," ~to!string(sunLightValue) ~ ",";
        return ret;
    }
}

immutable INVALID_TILE = Tile(0, TileFlags.none);


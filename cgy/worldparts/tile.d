
module worldparts.tile;

import util;

struct TileType{
    int graphTileId;
    int materialId;
    
    //Hmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm
    vec3i tint;
    vec3i materialTint;
    
    int strenth;
}

const ushort TileTypeInvalid    = 0;
const ushort TileTypeAir        = 1;

enum TileFlags : ushort {
    none        = 0,
    seen        = 1 << 0,
    transparent = 1<<2,
    valid       = 1 << 7,
}

struct Tile {
    ushort type = TileTypeInvalid;
    TileFlags flags = TileFlags.none;
    ushort hp = 0;
    ushort textureTile = 0;
    
    bool valid() const @property { return (flags & TileFlags.valid) != 0; }
    void valid(bool val) @property { setFlag(flags, TileFlags.valid, val); }

    bool seen() const @property { return (flags & TileFlags.seen) != 0; }
    void seen(bool val) @property { setFlag(flags, TileFlags.seen, val); }

    bool transparent() const @property { return (flags & TileFlags.transparent) != 0; }
    void transparent(bool val) @property { setFlag(flags, TileFlags.transparent, val); }
}

enum INVALID_TILE = Tile(TileTypeInvalid, TileFlags.none, 0, 0);


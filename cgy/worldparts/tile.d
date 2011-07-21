
module worldparts.tile;

import util;

//TODO: Remove transparent property from TileFlags / Tiles. See comment for transparent-flag.
//TODO: Make things private?


enum TileFlags : ushort {
    none        = 0,
    seen        = 1 << 0,
    transparent = 1 << 2, //TO REMOVE: There are no tile types which are transparent except for air!! :P
    pathable    = 1 << 4,
    valid       = 1 << 15,
}

struct Tile {
    ushort type;
    TileFlags flags = TileFlags.none;
    ushort hp = 0;
    ushort derp;

    bool valid() const @property { return (flags & TileFlags.valid) != 0; }
    void valid(bool val) @property { setFlag(flags, TileFlags.valid, val); }

    bool seen() const @property { return (flags & TileFlags.seen) != 0; }
    void seen(bool val) @property { setFlag(flags, TileFlags.seen, val); }

    bool transparent() const @property { return (flags & TileFlags.transparent) != 0; }
    void transparent(bool val) @property { setFlag(flags, TileFlags.transparent, val); }

    bool pathable() const @property { return (flags & TileFlags.pathable) != 0; }
    void pathable(bool val) @property { setFlag(flags, TileFlags.pathable, val); }
}

enum INVALID_TILE = Tile(0, TileFlags.none, 0, 0);



module worldparts.tile;

import util;

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

enum TileFlags : ushort {
    none        = 0,
    seen        = 1 << 0,
    transparent = 1 << 2,
    halfstep    = 1 << 3,
    valid       = 1 << 7,
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

    bool halfstep() const @property { return (flags & TileFlags.halfstep) != 0; }
    void halfstep(bool val) @property { setFlag(flags, TileFlags.halfstep, val); }
}

enum INVALID_TILE = Tile(0, TileFlags.none, 0, 0);


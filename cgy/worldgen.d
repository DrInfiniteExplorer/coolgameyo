
import std.math, std.conv;

import tilesystem;
import world;
import util;
import pos;

struct WorldGenParams {
    uint randomSeed;
}

private float foo(float x, float y) {
//    return 4*sin(x/10.0) + 24*atan(y/50.0) - 2*cos(y/3.0);
//    return 4*sin(x/10.f) - 2*cos(y/13.f);
    return 4*sin(x/10.0) + 24*atan(y/50.0);
}

class WorldGenerator {
    TileSystem sys;

    ushort air;
    ushort mud;

    this(TileSystem tileSystem) {
        sys = tileSystem;
        air = sys.idByName("air");
        mud = sys.idByName("mud");
    }

    Tile getTile(const TilePos pos) {
        auto top = foo(to!float(pos.value.X), to!float(pos.value.Y));
        auto Z = pos.value.Z;
        auto d = top - Z;

        Tile ret;
        if (0 < d && d < 0.5) {
            ret = Tile(mud, TileFlags.halfstep, 0, 0);
        } else if (0 <= d) {
            ret = Tile(mud, TileFlags.none, 0, 0);
        } else {
            ret = Tile(air, TileFlags.transparent, 0, 0);
        }
        ret.valid = true;

        return ret;
    }
    int maxZ(const TileXYPos xypos) {
        return to!int(foo(to!float(xypos.value.X), to!float(xypos.value.Y)));
    }
}


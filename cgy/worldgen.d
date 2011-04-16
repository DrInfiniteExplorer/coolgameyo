
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

    ushort air, mud, rock, water;

    this(TileSystem tileSystem) {
        sys = tileSystem;
        air = sys.idByName("air");
        mud = sys.idByName("mud");
        rock = sys.idByName("rock");
        water = sys.idByName("water");
    }

    Tile getTile(const TilePos pos) {
        auto top = foo(to!float(pos.value.X), to!float(pos.value.Y));
        auto Z = pos.value.Z;
        auto d = top - Z;

        Tile ret;

        auto groundType = Z > 11 ? mud : rock;
        auto airType = Z > 5 ? air : water;
        auto transparent = airType == air ?
            TileFlags.transparent : TileFlags.none;
        if (0 < d && d < 0.5) {
            ret = Tile(groundType, TileFlags.halfstep, 0, 0);
        } else if (0 <= d) {
            ret = Tile(groundType, TileFlags.none, 0, 0);
        } else {
            ret = Tile(airType, transparent, 0, 0);
        }
        ret.valid = true;

        return ret;
    }
    int maxZ(const TileXYPos xypos) {
        return to!int(foo(to!float(xypos.value.X), to!float(xypos.value.Y)));
    }
}


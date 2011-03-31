import std.math, std.conv;

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
    this() { }

    Tile getTile(const TilePos pos) {
        auto z = foo(to!float(pos.value.X), to!float(pos.value.Y));
        return pos.value.Z > z
            ? Tile(TileType.air, TileFlags.none, 0, 0)
            : Tile(TileType.retardium, TileFlags.none, 0, 0);
    }
    int maxZ(const TileXYPos xypos) {
        return to!int(foo(to!float(xypos.value.X), to!float(xypos.value.Y)));
    }
}

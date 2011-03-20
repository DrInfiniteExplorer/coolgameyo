import std.math, std.conv;

import world;
import stuff;

struct WorldGenParams {
    uint randomSeed;
}

private float foo(float x, float y) {
    return 4*sin(x/10) + 24*atan(y/50) - 2*cos(y/3);
}

class WorldGenerator {
    this() { }

    Tile getTile(const vec3i pos) {
        auto z = foo(to!float(pos.X), to!float(pos.Y));
        return pos.Z > z
            ? Tile(TileType.air, TileFlags.none, 0, 0)
            : Tile(TileType.retardium, TileFlags.none, 0, 0);
    }
    int maxZ(const vec2i xypos) {
        return to!int(foo(to!float(xypos.X), to!float(xypos.Y)));
    }
}

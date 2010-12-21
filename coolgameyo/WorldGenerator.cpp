#include "WorldGenerator.h"


WorldGenerator::WorldGenerator(void)
{
}


WorldGenerator::~WorldGenerator(void)
{
}

Tile getTile(vec3i pos) {

    static Tile air(0,0,0,0);
    static Tile ground(1,0,0,0);

    auto x = pos.X;
    auto y = pos.Y;
    auto z = pos.Z;

    return z > 10 * sin(x / 10.0) + 100 * atan(y/100.0) ? air : ground;
}


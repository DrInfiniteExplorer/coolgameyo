#include "WorldGenerator.h"


WorldGenerator::WorldGenerator(void)
{
}


WorldGenerator::~WorldGenerator(void)
{
}

Tile WorldGenerator::getTile(const vec3i &pos) {

    static Tile air = {ETT_AIR,0,0,0};
    static Tile ground = {ETT_RETARDIUM,0,0,0};

    float x = (float)pos.X;
    float y = (float)pos.Y;
    float z = (float)pos.Z;

    auto temp = 10 * sin(x / 10.0) + 100 * atan(y/100.0) - 2 * cos(y/3);

    return z > temp ? air : ground;
}


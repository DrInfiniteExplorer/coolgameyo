#include "WorldGenerator.h"


WorldGenerator::WorldGenerator(void)
{
}


WorldGenerator::~WorldGenerator(void)
{
}

inline float foo(float x, float y)
{
    return (float)(10 * sin(x / 10.0) + 100 * atan(y/100.0) - 2 * cos(y/3));
}

Tile WorldGenerator::getTile(const vec3i pos)
{

    static Tile air = {ETT_AIR,0,TILE_VALID,0};
    static Tile ground = {ETT_RETARDIUM,0,TILE_VALID,0};

    float x = (float)pos.X;
    float y = (float)pos.Y;
    float z = (float)pos.Z;

    auto temp = foo(x,y);

    //return z > 10 + 10*sin(x*0.1) ? air : ground;
    return z > temp ? air : ground;
}

s32 WorldGenerator::maxZ(const vec2i xypos)
{
    return (s32)foo((float)xypos.X,(float)xypos.Y) + 1;
}
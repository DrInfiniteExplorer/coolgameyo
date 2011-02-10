#pragma once

#include "include.h"
#include "Tile.h"

struct WorldGenParams
{
    u32 RandomSeed;
    /* MOAR PARAMETERS! */
};




class WorldGenerator
{
public:
    WorldGenerator(void);
    ~WorldGenerator(void);

    Tile getTile(const vec3i pos);
    s32 maxZ(const vec2i xypos);
};


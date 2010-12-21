#pragma once

#include "include.h"
#include "Tile.h"

struct WorldGenParams{
    u32 RandomSeed;
    /* MOAR PARAMETERS! */
};




class WorldGenerator
{
public:
    WorldGenerator(void);
    ~WorldGenerator(void);

    Tile getTile(vec3i pos);
};


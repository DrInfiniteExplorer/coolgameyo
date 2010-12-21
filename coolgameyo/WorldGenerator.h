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

    void getTile(vec3i position, Tile &outTile); //Derp by using reference we dont need to create intermediate instances etc
};


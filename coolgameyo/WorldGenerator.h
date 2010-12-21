#pragma once

#include "include.h"
#include "Tile.h"

struct WorldGenParams{
    u32 RandomSeed;
    /* MOAR PARAMETERS! */
};




class WorldGenerator
{
    WorldGenerator(void);
    ~WorldGenerator(void);

    void getTile(iVec position, Tile &outTile); //Derp by using reference we dont need to create intermediate instances etc
};


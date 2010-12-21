#pragma once

#include "include.h"

enum E_TILE_TYPES {
    ETT_AIR,
    ETT_RETARDIUM,
};

#define TILE_SEEN     (1<<0)

#pragma pack(push, 1)
struct Tile
{
    u16 type;	//Maps to E_TILE_TYPES. Durr would be awesome to force E_TILE_TYPES to be 16 bits big instead herp a derp.
    u16 hp;
    u16 flags;
    u16 derp;
};
#pragma pack(pop)

static_assert(sizeof(Tile) == 8, "Size of tile != 8 bytes :( :( :(");


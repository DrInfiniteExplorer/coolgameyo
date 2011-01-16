#pragma once

#include "include.h"

#include "serialization.h"

enum E_TILE_TYPES {
    ETT_AIR,
    ETT_RETARDIUM,
};

#define TILE_SEEN       (1<<0)

#define TILE_SPARSE     (1<<6)
#define TILE_INVALID    (1<<7)

#define TILE_VISIBLE(X)      (!( (X.flags)&(TILE_SPARSE|TILE_INVALID)))  /*  All tiles except sparse and invalid tiles are visible?       */
                                                                         /*  Not air tiles!!!! (currently manual check besides this one)  */

#pragma pack(push, 1)
struct Tile
{
    bool operator==(const Tile &o){
        return type == o.type && hp == o.hp && flags == o.flags && textureTile == o.textureTile;
    }

    u16 type;	//Maps to E_TILE_TYPES. Durr would be awesome to force E_TILE_TYPES to be 16 bits big instead herp a derp.
    u16 hp;
    u16 flags;
    u16 textureTile;

    void writeTo(std::function<void(void*, size_t)> f)
    {
        f(this, sizeof(*this));
    }
    size_t readFrom(void* ptr, size_t size)
    {
        assert (size >= sizeof *this);
        memmove(this, ptr, sizeof *this);
        return sizeof *this;
    }
};
#pragma pack(pop)

static_assert(sizeof(Tile) == 8, "Size of tile != 8 bytes :( :( :(");

inline Tile INVALID_TILE(){
    Tile t={0, 0, TILE_INVALID, 0};
    return t;
}

inline Tile SPARSE_TILE(){
    Tile t={0, 0, TILE_SPARSE, 0};
    return t;
}

inline Tile AIR_TILE(){
    Tile t={ETT_AIR, 0, 0, 0};
    return t;
}

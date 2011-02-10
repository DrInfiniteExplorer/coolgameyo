#pragma once

#include "include.h"

#include "serialization.h"

enum E_TILE_TYPES {
    ETT_AIR,
    ETT_RETARDIUM,
};

#define TILE_SEEN       (1<<0)

#define TILE_VALID      (1<<7)

#pragma pack(push, 1)
struct Tile
{
    u16 type;	//Maps to E_TILE_TYPES. Durr would be awesome to force E_TILE_TYPES to be 16 bits big instead herp a derp.
    u16 hp;
    u16 flags;
    u16 textureTile;
    
    bool operator==(const Tile &o)
    {
        return type == o.type && hp == o.hp 
            && flags == o.flags && textureTile == o.textureTile;
    }

    int isValid() const { return GetFlag(flags, TILE_VALID); }
    void setValid(bool valid=true) { SetFlag(flags, TILE_VALID, valid); }

    int isSeen() const { return GetFlag(flags, TILE_SEEN); }
    void setSeen(bool seen=true) { SetFlag(flags, TILE_SEEN, seen); }
    
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
    Tile t={0,0,0,0};
    return t;
}

inline Tile AIR_TILE(){
    Tile t={ETT_AIR, 0, TILE_VALID, 0};
    return t;
}

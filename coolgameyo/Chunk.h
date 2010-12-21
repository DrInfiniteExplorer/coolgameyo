#pragma once


#include "include.h"
#include "Block.h"

#define CHUNK_SIZE_X    (8)
#define CHUNK_SIZE_Y    (8)
#define CHUNK_SIZE_Z    (4)

#define TILES_PER_CHUNK_X   (CHUNK_SIZE_X * BLOCK_SIZE_X)
#define TILES_PER_CHUNK_Y   (CHUNK_SIZE_Y * BLOCK_SIZE_Y)
#define TILES_PER_CHUNK_Z   (CHUNK_SIZE_Z * BLOCK_SIZE_Z)


class Chunk
{
private:
   vec3i getBlockPos(const vec3i &tilePos);
   vec3i getRelativeBlockPos(const vec3i &tilePos);

   BlockPtr    m_pBlocks[CHUNK_SIZE_X][CHUNK_SIZE_Y][CHUNK_SIZE_Z];

public:
   Chunk(void);
   ~Chunk(void);

   void getTile(const vec3i tilePos, Tile &outTile);

};

typedef Chunk *ChunkPtr;
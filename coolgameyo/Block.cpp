#include "Block.h"


Block::Block(void)
{
}


Block::~Block(void)
{
}

vec3i Block::getRelativeTilePosition(const vec3i &tilePosition){

   static_assert(0x7 == BLOCK_SIZE_X-1, "Derp");
   static_assert(0x7 == BLOCK_SIZE_Y-1, "Derp");
   static_assert(0x7 == BLOCK_SIZE_Z-1, "Derp");

   return vec3i(
      tilePosition.X & 0x7,
      tilePosition.Y & 0x7,
      tilePosition.Z & 0x7
      );

/*
   return vec3i(
      tilePosition.X % BLOCK_SIZE_X,
      tilePosition.Y % BLOCK_SIZE_Y,
      tilePosition.Z % BLOCK_SIZE_Z
   );
*/
}

Tile Block::getTile(const vec3i &tilePosition){
   /* Remove this sometime? */
   vec3i relativeTilePosition = getRelativeTilePosition(tilePosition);
   return m_tiles[relativeTilePosition.X][relativeTilePosition.Y][relativeTilePosition.Z];
}

void Block::setTile(const vec3i &tilePosition, const Tile& newTile){
   /* Remove this sometime? */
   vec3i relativeTilePosition = getRelativeTilePosition(tilePosition);

   m_tiles[relativeTilePosition.X][relativeTilePosition.Y][relativeTilePosition.Z] = newTile;

   SetFlag(m_flags, BLOCK_UNSEEN, GetFlag(m_flags, BLOCK_UNSEEN) && !GetFlag(newTile.type, TILE_SEEN));
   SetFlag(m_flags, BLOCK_AIR,    GetFlag(m_flags, BLOCK_AIR)    && (newTile.type == ETT_AIR));
}

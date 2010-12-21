#include "Block.h"


Block::Block(void)
{
}


Block::~Block(void)
{
}

iVec3 Block::getRelativeTilePosition(const iVec3 &tilePosition){

   static_assert(0x7 == BLOCK_SIZE_X-1, "Derp");
   static_assert(0x7 == BLOCK_SIZE_Y-1, "Derp");
   static_assert(0x7 == BLOCK_SIZE_Z-1, "Derp");

   return iVec3(
      tilePosition.X & 0x7,
      tilePosition.Y & 0x7,
      tilePosition.Z & 0x7
      );

/*
   return iVec3(
      tilePosition.X % BLOCK_SIZE_X,
      tilePosition.Y % BLOCK_SIZE_Y,
      tilePosition.Z % BLOCK_SIZE_Z
   );
*/
}

void Block::GetTile(const iVec3 &tilePosition, Tile& outTile){
   /* Remove this sometime? */
   iVec3 relativeTilePosition = getRelativeTilePosition(tilePosition);
   outTile = m_tiles[relativeTilePosition.X][relativeTilePosition.Y][relativeTilePosition.Z];
}

void Block::SetTile(const iVec3 &tilePosition, const Tile& newTile){
   /* Remove this sometime? */
   iVec3 relativeTilePosition = getRelativeTilePosition(tilePosition);

   m_tiles[relativeTilePosition.X][relativeTilePosition.Y][relativeTilePosition.Z] = newTile;

   SetFlag(m_flags, BLOCK_UNSEEN, GetFlag(m_flags, BLOCK_UNSEEN) && !GetFlag(newTile.type, TILE_SEEN));
   SetFlag(m_flags, BLOCK_AIR,    GetFlag(m_flags, BLOCK_AIR)    && (newTile.type == ETT_AIR));
}

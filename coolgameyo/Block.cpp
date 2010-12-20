#include "Block.h"


Block::Block(void)
{
}


Block::~Block(void)
{
}

const Tile& Block::getTile(iVec relativeTilePosition){
   /* Remove this sometime? */
   relativeTilePosition.X %= BLOCK_SIZE_X;
   relativeTilePosition.Y %= BLOCK_SIZE_Y;
   relativeTilePosition.Z %= BLOCK_SIZE_Z;

   return m_tiles[relativeTilePosition.X][relativeTilePosition.Y][relativeTilePosition.Z];
}

void Block::setTile(iVec relativeTilePosition, Tile& newTile){
   /* Remove this sometime? */
   relativeTilePosition.X %= BLOCK_SIZE_X;
   relativeTilePosition.Y %= BLOCK_SIZE_Y;
   relativeTilePosition.Z %= BLOCK_SIZE_Z;

   m_tiles[relativeTilePosition.X][relativeTilePosition.Y][relativeTilePosition.Z] = newTile;

   SetFlag(m_flags, BLOCK_UNSEEN, GetFlag(m_flags, BLOCK_UNSEEN) && !GetFlag(newTile.type, TILE_SEEN));
   SetFlag(m_flags, BLOCK_AIR, GetFlag(m_flags, BLOCK_AIR) && (newTile.type == ETT_AIR));
}

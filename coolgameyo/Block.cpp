#include "Block.h"
#include "Util.h"

Block::Block(void)
{
}


Block::~Block(void)
{
}

Tile Block::getTile(const vec3i &tilePosition){
   /* Remove this sometime? */
   vec3i relativeTilePosition = GetBlockRelativeTilePosition(tilePosition);
   return m_tiles[relativeTilePosition.X][relativeTilePosition.Y][relativeTilePosition.Z];
}

void Block::setTile(const vec3i &tilePosition, const Tile& newTile){
   /* Remove this sometime? */
   vec3i relativeTilePosition = GetBlockRelativeTilePosition(tilePosition);

   m_tiles[relativeTilePosition.X][relativeTilePosition.Y][relativeTilePosition.Z] = newTile;

   SetFlag(m_flags, BLOCK_UNSEEN, GetFlag(m_flags, BLOCK_UNSEEN) && !GetFlag(newTile.type, TILE_SEEN));
   SetFlag(m_flags, BLOCK_AIR,    GetFlag(m_flags, BLOCK_AIR)    && (newTile.type == ETT_AIR));
}

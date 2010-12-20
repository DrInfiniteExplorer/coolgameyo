#pragma once

#include "include.h"
#include "Tile.h"

#define BLOCK_SIZE_X (8)
#define BLOCK_SIZE_Y (8)
#define BLOCK_SIZE_Z (8)

#define BLOCK_UNSEEN		(1<<0)
#define BLOCK_AIR			(1<<1)

class Block
{
public:
	Block(void);
	~Block(void);

	const Tile &GetTile(iVec relativeTilePosition);
	void SetTile(iVec relativeTilePosition, Tile& tile);


private:

	//Keep position of block like this or should instance above keep block position?
	iVec	m_worldPos; //Position of (upper left front?? derp) corner?

	/* Really make this private? */
	Tile	m_tiles[BLOCK_SIZE_X][BLOCK_SIZE_Y][BLOCK_SIZE_Z];

	u8		m_flags;
};


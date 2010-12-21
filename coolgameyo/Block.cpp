#include "Block.h"
#include "Util.h"
#include "WorldGenerator.h"

Block::Block(void)
{
    m_flags = BLOCK_AIR | BLOCK_UNSEEN;
}


Block::~Block(void)
{
}

void Block::generateBlock(const vec3i &tilePos, WorldGenerator *pWorldGen){
    vec3i blockPos = GetBlockWorldPosition(tilePos);
    printf("Generating block @ %d\t%d\t%d\n", blockPos.X, blockPos.Y, blockPos.Z);
    vec3i pos;
    for(int x=0;x<BLOCK_SIZE_X;x++){
        pos.X = blockPos.X + x;
        for(int y=0;y<BLOCK_SIZE_Y;y++){
            pos.Y = blockPos.Y + y;
            for(int z=0;z<BLOCK_SIZE_Z;z++){
                pos.Z = blockPos.Z + z;
                m_tiles[x][y][z] = pWorldGen->getTile(pos);
            }
        }
    }
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






void Block::render(IVideoDriver *pDriver){
    static aabbox3df box(vector3df(0.5f, 0.5f, 0.5f));
    SMaterial mat;
    mat.Lighting = false;
    mat.Wireframe = true;
    pDriver->setMaterial(mat);
    matrix4 matr;
    pDriver->getTransform(ETS_WORLD);
    vec3f blockPos = matr.getTranslation();
    vec3f pos;
    for(int x=0;x<BLOCK_SIZE_X;x++){
        pos.X = blockPos.X + x;
    for(int y=0;y<BLOCK_SIZE_Y;y++){
        pos.Y = blockPos.Y + y;
    for(int z=0;z<BLOCK_SIZE_Z;z++){
        pos.Z = blockPos.Z + z;
        matr.setTranslation(pos);
        pDriver->setTransform(ETS_WORLD, matr);
        pDriver->draw3DBox(box);
    }
    }
    }
}



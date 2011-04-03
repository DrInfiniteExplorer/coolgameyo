
module worldparts.sector;

import std.container;

import worldparts.block;
import worldgen;
import pos;
import unit;

enum BlocksPerSector {
    x = 16,
    y = 16,
    z = 4,
    total = x*y*z
}

enum SectorSize {
    x = BlockSize.x * BlocksPerSector.x,
    y = BlockSize.y * BlocksPerSector.y,
    z = BlockSize.z * BlocksPerSector.z,
    total = x*y*z
}

//We may want to experiment with these values, or even make it a user settingable setting. Yeah.
enum GraphRegionSize {
    x = BlockSize.x,
    y = BlockSize.y,
    z = BlockSize.z,
    total = x*y*z
}

class Sector {

    TilePos pos;
    SectorNum sectorNum;
    int blockCount;

    Block[BlocksPerSector.z][BlocksPerSector.y][BlocksPerSector.x] blocks;
    static assert(blocks.length == BlocksPerSector.x);
    

    RedBlackTree!(Unit*) units;
    int activityCount;

    invariant(){
        assert(sectorNum.toTilePos() == pos);
        assert(pos.getSectorNum() == sectorNum);
        assert(activityCount >= 0);
    }

    this(SectorNum sectorNum_) {
        sectorNum = sectorNum_;
        pos = sectorNum.toTilePos();
        units = typeof(units)(cast(Unit*[])[]); //Retarded. RBTree-initialization.
    }

    const(Block)[] getBlocks() const {
        return (&blocks[0][0][0])[0 .. BlocksPerSector.total];
    }

    void generateBlock(BlockNum blockNum, WorldGenerator worldGen)
    in{
        assert(blockNum.getSectorNum() == sectorNum, "Trying to generate a block in the wrong sector!");
        assert(blockNum.getSectorNum.toTilePos() == pos); //Good to have? In that case, add to other places like getBlock() as well.
    }
    body{
        auto pos = blockNum.rel();
        blocks[pos.X][pos.Y][pos.Z] = Block.generateBlock(blockNum, worldGen);
    }

    Block getBlock(BlockNum blockNum)
    in{
        assert(blockNum.getSectorNum() == sectorNum);
    }
    body{        
        auto pos = blockNum.rel();
        return blocks[pos.X][pos.Y][pos.Z];
    }
    
    void setBlock(BlockNum blockNum, Block newBlock)
    in{
        assert(blockNum.getSectorNum() == sectorNum, "Sector.setBlock: Trying to set a block that doesn't belong here!");
    }
    body{        
        auto rel = blockNum.rel();
        auto currentBlock = blocks[rel.X][rel.Y][rel.Z];
        if(currentBlock.valid && !currentBlock.sparse){
            if(currentBlock.tiles.ptr != newBlock.tiles.ptr){
                assert(0, "We want to free this memory i think...The current, that is.");                
            }
        }
        blocks[rel.X][rel.Y][rel.Z] = newBlock;
    }

    void addUnit(Unit* u) {
        units.insert(u);
    }
    void increaseActivity() {
        bool wasLoaded = activityCount==0;
        activityCount += 1;
        if( wasLoaded ){
        }
    }
}


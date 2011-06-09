//TODO: Lots of stuff
//TODO: make members private etc


module worldparts.sector;

import std.container;
import std.exception;
import std.stdio;

import worldparts.block;
import worldgen;
import pos;
import unit;
import util;

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

//TODO: UPDATE THESE MEASUREMENT VALUES
//We may want to experiment with these values, or even make it a user settingable setting. Yeah.
// blocksize * 2 gives ~30 ms per block and a total of ~3500-3700 per sector
// blocksize * 4 gives ~500 ms per block and a total of ~3500 per sector
// blocksize * 2 seems more do-want-able since its faster when updating, yeah.
enum GraphRegionSize {
    x = BlockSize.x*2,
    y = BlockSize.y*2,
    z = BlockSize.z*2,
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
        ASSERT(sectorNum.toTilePos() == pos);
        ASSERT(pos.getSectorNum() == sectorNum);
        ASSERT(activityCount >= 0);
    }

    this(SectorNum sectorNum_) {
        sectorNum = sectorNum_;
        pos = sectorNum.toTilePos();
        units = new typeof(units);
    }

    //TODO: Validate this code
    const(Block)[] getBlocks() const {
        return (&blocks[0][0][0])[0 .. BlocksPerSector.total];
    }

    //TODO: What about if there already was a block there?
    //   potential solution; use setBlock ?
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
    in {
        assert(blockNum.getSectorNum() == sectorNum, "Sector.setBlock: Trying to set a block that doesn't belong here!");
    }
    body {
        auto rel = blockNum.rel();
        auto currentBlock = blocks[rel.X][rel.Y][rel.Z];
        //TODO: Make comment detailing the logic behind this
        //TODO: make use of block.isSame ?
        if(currentBlock.valid && !currentBlock.sparse){
            if(currentBlock.tiles.ptr != newBlock.tiles.ptr){
                writeln("Make fix this");
                //TODO: Make fix line below!
                //enforce(0, "We want to free this memory i think...The current, that is.");
            }
        }
        blocks[rel.X][rel.Y][rel.Z] = newBlock;
    }

    //TODO: Add more unit-interfacing etc.
    void addUnit(Unit* u) {
        units.insert(u);
    }

    void increaseActivity() { activityCount += 1; }
    void decreaseActivity() { activityCount -= 1; }
}


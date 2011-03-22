import std.algorithm, std.range, std.stdio;
import std.container;
import std.exception;

import worldgen;
import unit;

import util;

interface WorldListener {
    void notifySectorLoad(SectorNum sectorNum);
    void notifySectorUnload(SectorNum sectorNum);
    void notifyTileChange(TilePos tilePos);
}


class World {

    struct SectorXY {
        int[SectorSize.x][SectorSize.y]* heightmap;
        Sector[int] sectors;
    }

    SectorXY[SectorXYNum] sectorXY;
    Sector[] sectorList;

    WorldGenerator worldGen;
    bool isServer;

    int unitCount;
    
    WorldListener[] listeners;

    this() {
        isServer = true;
        worldGen = new WorldGenerator();

        // do this in main() or something? D:
        auto xy = tileXYPos(vec2i(8,8));
        auto u = new Unit;
        u.pos = getTopTilePos(xy).value;
        u.pos.Z += 1;
        addUnit(u);

        floodFillVisibility(xy);
    }

    void generateBlock(BlockNum blockNum) {
        //Was toSectorPos insted of getSectorNumber which i'm guessing it's supposed to be.
        //Discovered after fixing this that getSector takes a tilepos and internally uses
        // "toSectorPos" ie. getSectorNumber. So removing that call here.
        getSector(blockNum.getSectorNum()).generateBlock(blockNum, worldGen); 
    }

    SectorXY getSectorXY(SectorXYNum xy) {
        
        if(xy in sectorXY){
            return sectorXY[xy];
        }
        SectorXY ret;
        static assert ((*ret.heightmap).sizeof == 
                int.sizeof * SectorSize.x * SectorSize.y);
        int[] blob = new int[](SectorSize.x * SectorSize.y);
        blob[] = 0;
        auto heightmap = cast(typeof(ret.heightmap))(blob.ptr);
        ret.heightmap = heightmap;
        
        auto p = xy.getTileXYPos();
        
        int xxx=-1;
        
        foreach(relPos ; RangeFromTo(0, SectorSize.x, 0, SectorSize.y, 0, 1)){            
            xxx = relPos.Y;
            writeln(relPos.X, " ", xxx, " ", relPos.Z);
            auto tmp = p.value + vec2i(relPos.X, relPos.Y);
            auto posXY = tileXYPos(tmp);
            auto z = worldGen.maxZ(posXY);
            while (worldGen.getTile(tilePos(posXY, z)).type == TileType.air) {
                z -= 1;
            }
            
            (*heightmap)[relPos.X][relPos.Y] = z;            
        }        

        writeln("Needs some heightmap generation at ", xy);
        
        sectorXY[xy] = ret; //Spara det vi skapar, yeah!    
        return ret;
    }

    Sector allocateSector(SectorNum sectorNum) {
        auto xy = sectorXYNum(vec2i(sectorNum.value.X, sectorNum.value.Y));
        auto z = sectorNum.value.Z;

        if (xy !in sectorXY) {
            sectorXY[xy] = getSectorXY(xy);
        }

        auto sector = new Sector(sectorNum);

        assert (z !in sectorXY[xy].sectors);
        sectorXY[xy].sectors[z] = sector;
        sectorList ~= sector;

        return sector;
    }

    Sector getSector(SectorNum sectorNum, bool get=true) {
        auto xy = SectorXYNum(vec2i(sectorNum.value.X, sectorNum.value.Y));
        auto z = sectorNum.value.Z;

        if (xy in sectorXY && z in sectorXY[xy].sectors) {
            return sectorXY[xy].sectors[z];
        }
        return get ? allocateSector(sectorNum) : null;
    }

    Block getBlock(BlockNum blockNum, bool generate=true, bool getSector=false) {
        auto sector = this.getSector(blockNum.getSectorNum(), getSector);
        if (sector is null) return INVALID_BLOCK;

        auto block = sector.getBlock(blockNum);
        if (!block.valid) {
            if (!generate) return INVALID_BLOCK;

            generateBlock(blockNum);
            block = sector.getBlock(blockNum);
        }
        assert (block.valid);
        return block;
    }
    
    void setBlock(BlockNum blockNum, Block newBlock) {
        assert (false);
    }

    Sector[] lock() { return sectorList; }

    void addUnit(Unit* unit) {
        unitCount += 1;
        auto sectorNum = unit.tilePosition.getSectorNum();
        auto sector = getSector(sectorNum);
        sector.addUnit(unit);
        
        foreach (dpos; RangeFromTo(-2,3,-2,3,-2,3)) {
            auto pos = unit.tilePosition.getSectorNum();
            pos.value.X +=  dpos.X;
            pos.value.Y +=  dpos.Y;
            pos.value.Z +=  dpos.Z;
            getSector(pos).increaseActivity();
        }
    }

    Tile getTile(TilePos tilePos, bool createBlock=true,
                                  bool createSector=true) {
        return getBlock(tilePos.getBlockNum(), createBlock, createSector)
            .getTile(tilePos);
    }
    void setTile(TilePos tilePos, const Tile newTile) {
        getBlock(tilePos.getBlockNum()).setTile(tilePos, newTile);
        notifyTileChange(tilePos);
    }

    TilePos getTopTilePos(TileXYPos xy) {
        auto x = xy.value.X;
        auto y = xy.value.Y;
        
        auto sectorXY = getSectorXY(xy.getSectorXYNum());
        
        auto heightmapPtr = sectorXY.heightmap;
        auto pos = vec3i(x, y, (*heightmapPtr)[x][y]);
        return tilePos(pos);        
    }

    void floodFillVisibility(const TileXYPos xyStart) {
        auto startPos = getTopTilePos(xyStart);
        startPos.value += vec3i(0,0,1);

        RedBlackTree!(BlockNum, q{a.value < b.value}) work;
        work.insert(startPos.getBlockNum());

        while (!work.empty) {
            auto pos = work.removeAny();

            auto block = getBlock(pos);
            if (!block.valid || block.seen) { continue; }

            block.seen = true;

            scope (exit) setBlock(pos, block);

            if (block.sparse) {
                if (block.type == TileType.air) {
                    work.insert(blockNum(pos.value + vec3i(1, 0, 0)));
                    work.insert(blockNum(pos.value - vec3i(1, 0, 0)));
                    work.insert(blockNum(pos.value + vec3i(0, 1, 0)));
                    work.insert(blockNum(pos.value - vec3i(0, 1, 0)));
                    work.insert(blockNum(pos.value + vec3i(0, 0, 1)));
                    work.insert(blockNum(pos.value - vec3i(0, 0, 1)));
                } else {
                    assert (0, "WAPAW PWAP WAPWPA PWA ");
                }
                continue;
            }
            
            foreach (rel; 
                    RangeFromTo(0,BlockSize.x,0,BlockSize.y,0,BlockSize.z)) {
                auto tp = tilePos(pos.toTilePos().value + rel);
                auto tile = block.getTile(tp);

                scope (exit) block.setTile(tp, tile);

                if (tile.type == TileType.air) {
                    tile.seen = true;
                    if (rel.X == 0) {
                        work.insert(blockNum(pos.value - vec3i(1,0,0)));
                    } else if (rel.X == BlockSize.x - 1) {
                        work.insert(blockNum(pos.value - vec3i(1,0,0)));
                    }
                    if (rel.Y == 0) {
                        work.insert(blockNum(pos.value - vec3i(0,1,0)));
                    } else if (rel.Y == BlockSize.y - 1) {
                        work.insert(blockNum(pos.value - vec3i(0,1,0)));
                    }
                    if (rel.Z == 0) {
                        work.insert(blockNum(pos.value - vec3i(0,0,1)));
                    } else if (rel.Z == BlockSize.z - 1) {
                        work.insert(blockNum(pos.value - vec3i(0,0,1)));
                    }
                } else {
                    foreach (npos; neighbors(tp)) {
                        auto neighbor = getTile(npos);
                        if (neighbor.valid && neighbor.type == TileType.air) {
                            tile.seen = true;
                            break;
                        }
                    }
                }
            }
        }
    }


    void addListener(WorldListener listener) {
        listeners ~= listener;
    }
    void removeListener(WorldListener listener) {
        remove(listeners, indexOf!q{a is b}(listeners, listener));
        listeners.length -= 1;
    }
    void notifySectorLoad(SectorNum sectorNum) {
        foreach (listener; listeners) {
            listener.notifySectorLoad(sectorNum);
        }
    }
    void notifySectorUnload(SectorNum sectorNum) {
        foreach (listener; listeners) {
            listener.notifySectorUnload(sectorNum);
        }
    }
    void notifyTileChange(TilePos tilePos) {
        foreach (listener; listeners) {
            listener.notifyTileChange(tilePos);
        }
    }
}

// SECTOR STUFF

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

    Block[BlocksPerSector.x][BlocksPerSector.y][BlocksPerSector.z] blocks;

    RedBlackTree!(Unit*) units;
    int activityCount;

    this(SectorNum sectorNum_) {
        pos = sectorNum.toTilePos();
        sectorNum = sectorNum_;
    }

    const(Block)[] getBlocks() const {
        return (&blocks[0][0][0])[0 .. BlocksPerSector.total];
    }

    void generateBlock(BlockNum blockNum, WorldGenerator worldGen)
    in{
        assert(blockNum.getSectorNum() == sectorNum);
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
    void setBlock(vec3i tilePos, Block newBlock) {
        auto pos = getBlockRelativeTileIndex(tilePos);
        blocks[pos.X][pos.Y][pos.Z] = newBlock;
    }

    void addUnit(Unit* u) {
        units.insert(u);
    }
    void increaseActivity() {
        activityCount += 1;
    }
}


// BLOCK STUFF

enum BlockSize {
    x = 8,
    y = 8,
    z = 8,
    total = x*y*z
}

enum BlockFlags : ubyte {
    none = 0,
    seen = 1 << 0,
    sparse = 1 << 1,
    dirty = 1 << 6,
    valid = 1 << 7,
}

struct Block {

    struct RenderData {
        ushort idxCnt;
        uint[2] VBO;
    }

    Tile[BlockSize.z][BlockSize.y][BlockSize.x]* tiles;

    BlockFlags flags;

    RenderData renderData;

    BlockNum blockNum;

    TileType type;

    static Block alloc() {
        assert (0);
    }
    static void free(Block block) {
        assert (0);
    }
    static Block generateBlock(BlockNum blockNum, WorldGenerator worldgen) {
        assert (0);
    }

    Tile getTile(TilePos tilePos)
    in{
        assert(tilePos.getBlockNum() == this.blockNum);
        assert (tiles);
    }
    body{
        auto pos = tilePos.rel();
        return (*tiles)[pos.X][pos.Y][pos.Z];
    }
    void setTile(TilePos pos, Tile tile)
    in{
        assert(pos.getBlockNum() == this.blockNum);
    }
    body{
        auto p = pos.rel();
        assert (0);
    }

    bool isSame(const Block other) const {
        return blockNum == other.blockNum && (sparse || tiles is other.tiles);
    }
    
    int valid() const @property { return flags & BlockFlags.valid; }
    void valid(bool val) @property { setFlag(flags, BlockFlags.valid, val); }

    int seen() const @property { return flags & BlockFlags.seen; }
    void seen(bool val) @property { setFlag(flags, BlockFlags.seen, val); }

    int sparse() const @property { return flags & BlockFlags.sparse; }
    void sparse(bool val) @property { setFlag(flags, BlockFlags.sparse, val); }

    int dirty() const @property { return flags & BlockFlags.dirty; }
    void dirty(bool val) @property { setFlag(flags, BlockFlags.dirty, val); }

    void clean(ushort idxCnt) {
        dirty = false;
        renderData.idxCnt = idxCnt;
    }
}

Block INVALID_BLOCK = {
    tiles :null,
    flags : BlockFlags.none,
    renderData : Block.RenderData(0,[0,0]),
    blockNum : blockNum(vec3i(int.min, int.min, int.min)),
    type : TileType.invalid
};

// TILE STUFF

enum TileType : ushort {
    invalid,
    air,
    retardium
}

enum TileFlags : ushort {
    none = 0,
    seen = 1 << 0,
    valid = 1 << 7,
}

struct Tile {
    TileType type;
    TileFlags flags;
    ushort hp;
    ushort textureTile;

    int valid() const @property { return flags & TileFlags.valid; }
    void valid(bool val) @property { setFlag(flags, TileFlags.valid, val); }

    int seen() const @property { return flags & TileFlags.seen; }
    void seen(bool val) @property { setFlag(flags, TileFlags.seen, val); }
}

enum INVALID_TILE = Tile(TileType.invalid, TileFlags.none, 0, 0);


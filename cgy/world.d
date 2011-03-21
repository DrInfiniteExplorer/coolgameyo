import std.algorithm, std.range, std.stdio;
import std.container;

import worldgen;
import unit;

import util;

interface WorldListener {
    void notifySectorLoad(vec3i sectorNum);
    void notifySectorUnload(vec3i sectorNum);
    void notifyTileChange(vec3i tilePos);
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

        // do this in main() or something? D:
        auto xy = vec2i(8,8);
        auto u = new Unit;
        u.pos = getTopTilePos(xy);
        u.pos.Z += 1;
        addUnit(u);

        floodFillVisibility(xy);
    }

    void generateBlock(BlockPos blockPos) {
        //Was toSectorPos insted of getSectorNumber which i'm guessing it's supposed to be.
        //Discovered after fixing this that getSector takes a tilepos and internally uses
        // "toSectorPos" ie. getSectorNumber. So removing that call here.
        getSector(blockPos.getSectorNum()).generateBlock(blockPos, worldGen); 
    }

    SectorXY getSectorXY(SectorXYNum xy) {
        SectorXY ret;
        static assert ((*ret.heightmap).sizeof == 
                int.sizeof * SectorSize.x * SectorSize.y);
        int[] blob = new int[](SectorSize.x * SectorSize.y);
        blob[] = 0;
        ret.heightmap = cast(typeof(ret.heightmap))(blob.ptr);

        writeln("Needs some heightmap generation at ", xy);

        return ret;
    }

    Sector allocateSector(SectorPos sectorNum) {
        auto xy = vec2i(sectorPos.value.X, sectorPos.value.Y);
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

    Sector getSector(TilePos tilePos, bool get=true) {
        auto sectorNum = tilePos.getSectorNum();
        auto xy = SectorXYNum(vec2i(sectorNum.value.X, sectorNum.value.Y))
        auto z = sectorNum.Z;

        if (xy in sectorXY && z in sectorXY[xy].sectors) {
            return sectorXY[xy].sectors[z];
        }
        return get ? allocateSector(sectorNum) : null;
    }

    Block getBlock(TilePos tilePos, bool generate=true, bool getSector=false) {
        auto sector = this.getSector(tilePos, getSector);
        if (sector is null) return INVALID_BLOCK;

        auto block = sector.getBlock(tilePos);
        if (!block.valid) {
            if (!generate) return INVALID_BLOCK;

            generateBlock(tilePos);
            block = sector.getBlock(tilePos);
        }
        assert (block.valid);
        return block;
    }
    
    void setBlock(TilePos tilePos, Block newBlock) {
        assert (false);
    }

    Sector[] lock() { return sectorList; }

    void addUnit(Unit* unit) {
        unitCount += 1;
        getSector(unit.pos).addUnit(unit);

        foreach (dpos; RangeFromTo(-2,3,-2,3,-2,3)) {
            auto pos = unit.pos;
            pos.X += SectorSize.x * dpos.X;
            pos.Y += SectorSize.y * dpos.Y;
            pos.Z += SectorSize.z * dpos.Z;
            getSector(pos).increaseActivity();
        }
    }

    Tile getTile(TilePos tilePos, bool createBlock=true,
                                  bool createSector=true) {
        return getBlock(tilePos, createBlock, createSector).getTile(tilePos);
    }
    void setTile(TilePos tilePos, const Tile newTile) {
        getBlock(tilePos).setTile(tilePos, newTile);
        notifyTileChange(tilePos);
    }

    TilePos getTopTilePos(TileXYPos xy) {
        auto x = xy.value.X, y = xy.value.Y;
        return tilePos(x, y, (*sectorXY[xy.getSectorXYNum()].heightmap)[x][y]);
    }

    void floodFillVisibility(const TileXYPos xyStart) {
        auto startPos = getTopTilePos(xyStart) + vec3i(0,0,1);

        RedBlackTree!BlockPos work;
        work.insert(startPos.getBlockPos());

        while (!work.empty) {
            auto pos = work.removeAny();

            auto block = getBlock(pos);
            if (!block.valid || block.seen) { continue; }

            block.seen = true;

            scope (exit) setBlock(pos, block);

            if (block.sparse) {
                if (block.type == TileType.air) {
                    work.insert(blockPos(pos.value + vec3i(1, 0, 0)));
                    work.insert(blockPos(pos.value - vec3i(1, 0, 0)));
                    work.insert(blockPos(pos.value + vec3i(0, 1, 0)));
                    work.insert(blockPos(pos.value - vec3i(0, 1, 0)));
                    work.insert(blockPos(pos.value + vec3i(0, 0, 1)));
                    work.insert(blockPos(pos.value - vec3i(0, 0, 1)));
                } else {
                    assert (0, "WAPAW PWAP WAPWPA PWA ");
                }
                continue;
            }
            
            foreach (rel; 
                    RangeFromTo(0,BlockSize.x,0,BlockSize.y,0,BlockSize.z)) {
                auto tp = tilePos(pos.getTilePos().value + rel);
                auto tile = block.getTile(tp);

                scope (exit) block.setTile(tp, tile);

                if (tile.type == TileType.air) {
                    tile.seen = true;
                    if (rel.X == 0) {
                        work.insert(blockPos(pos.value - vec3i(1,0,0)));
                    } else if (rel.X == BlockSize.x - 1) {
                        work.insert(blockPos(pos.value - vec3i(1,0,0)));
                    }
                    if (rel.Y == 0) {
                        work.insert(blockPos(pos.value - vec3i(0,1,0)));
                    } else if (rel.Y == BlockSize.y - 1) {
                        work.insert(blockPos(pos.value - vec3i(0,1,0)));
                    }
                    if (rel.Z == 0) {
                        work.insert(blockPos(pos.value - vec3i(0,0,1)));
                    } else if (rel.Z == BlockSize.z - 1) {
                        work.insert(blockPos(pos.value - vec3i(0,0,1)));
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
    void notifyTileChange(SectorPos tilePos) {
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
        assert(0); //Jag forstar nu vad du menar med att vi bor ha typer for att itne forvirra oss.
        pos = getSectorWorldPosition(sectorNum);
        sectorNum = sectorNum_;
    }

    const(Block)[] getBlocks() const {
        return (&blocks[0][0][0])[0 .. BlocksPerSector.total];
    }

    void generateBlock(vec3i tilePos, WorldGenerator worldGen) {
        auto pos = getBlockWorldPosition(tilePos);
        blocks[pos.X][pos.Y][pos.Z] = Block.generateBlock(tilePos, worldGen);
    }

    Block getBlock(vec3i tilePos) {
        auto pos = getBlockWorldPosition(tilePos);
        return blocks[pos.X][pos.Y][pos.Z];
    }
    void setBlock(vec3i tilePos, Block newBlock) {
        auto pos = getBlockWorldPosition(tilePos);
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

    vec3i pos;

    TileType type;

    static Block alloc() {
        assert (0);
    }
    static void free(Block block) {
        assert (0);
    }
    static Block generateBlock(vec3i blockPos, WorldGenerator worldgen) {
        assert (0);
    }

    Tile getTile(vec3i pos) {
        assert (tiles);
        return (*tiles)[pos.X][pos.Y][pos.Z];
    }
    void setTile(vec3i pos, Tile tile) {
        assert (0);
    }

    bool isSame(const Block other) const {
        return pos == other.pos && (sparse || tiles is other.tiles);
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

Block INVALID_BLOCK = Block(null, BlockFlags.none, Block.RenderData(0,[0,0]),
        vec3i(int.min, int.min, int.min), TileType.invalid);

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


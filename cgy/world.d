import std.algorithm, std.range, std.stdio;
import std.container;

import worldgen;
import unit;

import stuff;

interface WorldListener {
    void notifySectorLoad(vec3i sectorPos);
    void notifySectorUnload(vec3i sectorPos);
    void notifyTileChange(vec3i tilePos);
}


class World {

    struct SectorXY {
        int[SectorSize.x][SectorSize.y]* heightmap;
        Sector[int] sectors;
    }

    SectorXY[vec2i] sectorXY;
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

    void generateBlock(vec3i tilePos) {
        getSector(toSectorPos(tilePos)).generateBlock(tilePos, worldGen);
    }

    SectorXY getSectorXY(vec2i xy) {
        SectorXY ret;
        static assert ((*ret.heightmap).sizeof == 
                int.sizeof * SectorSize.x * SectorSize.y);
        int[] blob = new int[](SectorSize.x * SectorSize.y);
        blob[] = 0;
        ret.heightmap = cast(typeof(ret.heightmap))(blob.ptr);
        return ret;
    }


    Sector allocateSector(vec3i sectorPos) {
        auto xy = vec2i(sectorPos.X, sectorPos.Y);
        auto z = sectorPos.Z;

        if (xy !in sectorXY) {
            sectorXY[xy] = getSectorXY(xy);
        }

        auto sector = new Sector(sectorPos);

        assert (z !in sectorXY[xy].sectors);
        sectorXY[xy].sectors[z] = sector;
        sectorList ~= sector;

        return sector;
    }

    Sector getSector(vec3i tilePos, bool get=true) {
        auto sectorPos = getSectorPos(tilePos);
        auto xy = vec2i(sectorPos.X, sectorPos.Y);
        auto z = sectorPos.Z;

        if (xy in sectorXY && z in sectorXY[xy].sectors) {
            return sectorXY[xy].sectors[z];
        }
        return get ? allocateSector(sectorPos) : null;
    }

    Block getBlock(vec3i tilePos, bool generate=true, bool getSector=false) {
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
    
    void setBlock(vec3i tilePos, Block newBlock) {
        assert (false);
    }

    Sector[] lock() { return sectorList; }

    void addUnit(Unit* unit) {
        unitCount += 1;
        getSector(unit.pos).addUnit(unit);

        foreach (dpos; Range3D(-2,3,-2,3,-2,3)) {
            auto pos = unit.pos;
            pos.X += SectorSize.x * dpos.X;
            pos.Y += SectorSize.y * dpos.Y;
            pos.Z += SectorSize.z * dpos.Z;
            getSector(pos).increaseActivity();
        }
    }

    Tile getTile(vec3i tilePos, bool createBlock=true, bool createSector=true) {
        return getBlock(tilePos, createBlock, createSector).getTile(tilePos);
    }
    void setTile(vec3i tilePos, const Tile newTile) {
        getBlock(tilePos).setTile(tilePos, newTile);
        notifyTileChange(tilePos);
    }

    vec3i getTopTilePos(vec2i xy) {
        return vec3i(xy.X, xy.Y, (*sectorXY[xy].heightmap)[xy.X][xy.Y]);
    }

    void floodFillVisibility(const vec2i xyStart) {
        auto startPos = getTopTilePos(xyStart) + vec3i(0,0,1);

        RedBlackTree!vec3i work;
        work.insert(getBlockWorldPosition(startPos));

        while (!work.empty) {
            auto pos = work.removeAny();

            auto block = getBlock(pos);
            if (!block.valid || block.seen) { continue; }

            block.seen = true;

            scope (exit) setBlock(pos, block);

            if (block.sparse) {
                if (block.type == TileType.air) {
                    work.insert(pos + vec3i(BlockSize.x, 0, 0));
                    work.insert(pos - vec3i(BlockSize.x, 0, 0));
                    work.insert(pos + vec3i(0, BlockSize.y, 0));
                    work.insert(pos - vec3i(0, BlockSize.y, 0));
                    work.insert(pos + vec3i(0, 0, BlockSize.z));
                    work.insert(pos - vec3i(0, 0, BlockSize.z));
                } else {
                    writeln("wpap wapwap pwa");
                    assert (0);
                }
                continue;
            }
            
            foreach (rel; Range3D(0,BlockSize.x,0,BlockSize.y,0,BlockSize.z)) {
                auto tp = rel+pos;
                auto tile = block.getTile(tp);

                scope (exit) block.setTile(tp, tile);

                if (tile.type == TileType.air) {
                    tile.seen = true;
                    if (rel.X == 0) {
                        work.insert(pos - vec3i(BlockSize.x,0,0));
                    } else if (rel.X == BlockSize.x - 1) {
                        work.insert(pos - vec3i(BlockSize.x,0,0));
                    }
                    if (rel.Y == 0) {
                        work.insert(pos - vec3i(BlockSize.y,0,0));
                    } else if (rel.Y == BlockSize.y - 1) {
                        work.insert(pos - vec3i(BlockSize.y,0,0));
                    }
                    if (rel.Z == 0) {
                        work.insert(pos - vec3i(BlockSize.z,0,0));
                    } else if (rel.Z == BlockSize.z - 1) {
                        work.insert(pos - vec3i(BlockSize.z,0,0));
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
    void notifySectorLoad(vec3i sectorPos) {
        foreach (listener; listeners) {
            listener.notifySectorLoad(sectorPos);
        }
    }
    void notifySectorUnload(vec3i sectorPos) {
        foreach (listener; listeners) {
            listener.notifySectorUnload(sectorPos);
        }
    }
    void notifyTileChange(vec3i tilePos) {
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

alias RedBlackTree!(Unit*) UnitSet;

class Sector {

    vec3i pos;
    vec3i sectorPos;
    
    int blockCount;

    Block[BlocksPerSector.x][BlocksPerSector.y][BlocksPerSector.z] blocks;

    UnitSet units;
    int activityCount;

    this(vec3i sectorPos_) {
        pos = sectorPosToTilePos(sectorPos);
        sectorPos = sectorPos_;
    }

    const(Block)[] getBlocks() const {
        return (&blocks[0][0][0])[0 .. BlocksPerSector.total];
    }

    void generateBlock(vec3i tilePos, WorldGenerator worldGen) {
        auto pos = getBlockPos(tilePos);
        blocks[pos.X][pos.Y][pos.Z] = Block.generateBlock(tilePos, worldGen);
    }

    Block getBlock(vec3i tilePos) {
        auto pos = getBlockPos(tilePos);
        return blocks[pos.X][pos.Y][pos.Z];
    }
    void setBlock(vec3i tilePos, Block newBlock) {
        auto pos = getBlockPos(tilePos);
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


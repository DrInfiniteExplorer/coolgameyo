
//TODO: Remove block-sparse-transparency.
//TODO: Move code for block-allocator elsewhere
//TODO: Make things private?


module world.block;

import std.algorithm;
import std.exception;
import std.stdio;

import light;
import pos;
import tiletypemanager : TileTypeAir;
//import tiletypemanager;

//import worldgen.worldgen;
import worldgen.newgen;
import world.tile;
import world.sizes;
import util.memory;
import util.rangefromto;
import util.util;




enum BlockFlags : ubyte {
    none                = 0,
    sparse              = 1 << 1,
    hasAir              = 1 << 2,
    valid               = 1 << 7,
}

struct BlockTiles {
    Tile[BlockSize.z][BlockSize.y][BlockSize.x] tiles;
}

struct Block {

    BlockTiles* tiles = null;

    BlockFlags flags = BlockFlags.none;

    BlockNum blockNum = BlockNum(vec3i(int.min, int.min, int.min));

    ushort sparseTileType;
    byte sunLightVal;
    bool sparseTileTransparent() @property { return sparseTileType == TileTypeAir; }

    void destroy() {

        if(valid && !sparse) {
            enforce(tiles !is null, "gerp blerpo");
            free(this);
            tiles = null;
            flags = BlockFlags.none;
        }
    }

    //invariant()
    //{
    //    auto valid = flags & BlockFlags.valid;
    //    auto sparse = flags & BlockFlags.sparse;
      
    //    if (sparse) {
    //        assert(valid, "Block is marked as sparse, but doesn't have valid flag");
    //        assert(tiles is null, "Block is marked as sparse, but has tiles!");
    //    } else if (valid) {
    //        assert(tiles !is null, "Block is not sparse but valid, but doesn't have any tiles!");
    //    } else {
    //        assert(tiles is null, "Block is not valid, but has tiles!");
    //    }
    //}
    // fuck the system

    Tile sparseTile() {
        Tile t;
        t.type = sparseTileType;
        t.flags = TileFlags.valid;
        t.sunLightValue = sunLightVal;
        return t;
    }

    Tile getTile(TilePos tilePos) {
        assert(tilePos.getBlockNum() == this.blockNum);
        assert(valid);
        if (sparse) {
            return sparseTile();
        }
        auto pos = tilePos.rel();
        return tiles.tiles[pos.X][pos.Y][pos.Z];
    }

    void unsparsify() {
        assert (sparse);
        auto block = alloc();
        tiles = block.tiles;
        (&tiles.tiles[0][0][0])[0 .. BlockSize.total][] = sparseTile();
        sparse = false;
    }


    void setTile(TilePos pos, Tile tile)
    in{
        assert(pos.getBlockNum() == this.blockNum);
    }
    body{
        assert(valid);
        auto p = pos.rel();

        if (sparse) {
            unsparsify();
        }
        tiles.tiles[p.X][p.Y][p.Z] = tile;
    }

    void setTileLight(TilePos pos, const byte newVal, const bool isSunLight)
    in{
        assert(pos.getBlockNum() == this.blockNum);
    }
    body{
        assert(valid);
        auto p = pos.rel();

        if (sparse) {
            unsparsify();
        }

        tiles.tiles[p.X][p.Y][p.Z].setLight(isSunLight, newVal);
    }

    bool valid() const @property { return (flags & BlockFlags.valid) != 0; }
    void valid(bool val) @property { setFlag(flags, BlockFlags.valid, val); }

    bool hasAir() const @property { return (flags & BlockFlags.hasAir) != 0; }
    void hasAir(bool val) @property { setFlag(flags, BlockFlags.hasAir, val); }


    bool sparse() const @property { return (flags & BlockFlags.sparse) != 0; }
    void sparse(bool val) @property { setFlag(flags, BlockFlags.sparse, val); }
    
    void serialize(void delegate(const void[]) write)
    in{
        BREAK_IF(!valid);
    }
    body{
        auto a = [blockNum];
        write(a);
        auto b = [flags];
        write(b);
        if (sparse) {
            auto c = [sparseTileType];
            write(c);
            auto d = [sunLightVal];
            write(d);
        } else {
            BREAK_IF(tiles is null);            
            write((&tiles.tiles[0][0][0])[0 .. BlockSize.total]);
        }
    }
    
    void deserialize(void delegate(size_t size, ubyte* buff) read) {
        read(blockNum.sizeof, cast(ubyte*)&blockNum);
        read(flags.sizeof, cast(ubyte*)&flags);
        if ((flags & BlockFlags.sparse) != 0) {
            read(sparseTileType.sizeof, cast(ubyte*)&sparseTileType);
            read(sunLightVal.sizeof, cast(ubyte*)&sunLightVal);
        } else {
            auto block = alloc();
            tiles = block.tiles;
            static assert(BlockSize.total * Tile.sizeof == tiles.tiles.sizeof);
            read(tiles.tiles.sizeof, cast(ubyte*)&block.tiles.tiles);
            block.tiles = null;
        }
    }

    static Block generateBlock(BlockNum blockNum, WorldGenerator worldgen) {
        auto block = alloc();
        block.blockNum = blockNum;


        return worldgen.fillBlock(block);
    }


    // allocation / freelist stuff

    static {
        class Mutex {}
        Mutex mutex;
        private struct AllocationBlock {
            bool[] allocmap; // true = allocated, false = not
            BlockTiles[] data;

            //static assert (T.sizeof == 4096);

            enum dataSize = 128; //dataSize = number of T's to allocate

            AllocationBlock* next;

            BlockTiles* getMem() {
                auto i = allocmap.countUntil(false);
                if (i < 0) {
                    if (next is null) next = create();
                    return next.getMem();
                }
                assert (!allocmap[i]);
                allocmap[i] = true;
                return &data[i];
            }
            void returnMem(BlockTiles* mem) {
                auto diff = mem - data.ptr;
                if (0 <= diff && diff < dataSize) {
                    // IT IS OUR BLOB!!!!!
                    allocmap[diff] = false;
                } else {
                    BREAK_IF(next is null);
                    assert (next, "We have our buddie's blob, "~
                            "but our buddy is dead. Gosh darned it!");
                    next.returnMem(mem);
                }
            }

            static AllocationBlock* create() {
                auto alloc = new AllocationBlock;
                alloc.allocmap = new bool[](dataSize);
                auto blob = allocateBlob(dataSize, BlockTiles.sizeof);
                (cast(ubyte[])blob)[] = 0;
                alloc.data = cast(BlockTiles[])blob;
                return alloc;
            }
        }
        __gshared AllocationBlock* freeblock;

        Block alloc() {
            if(mutex is null) {
                mutex = new Mutex;
            }
            synchronized(mutex) {
                if (freeblock is null) {
                    freeblock = AllocationBlock.create();
                }

                Block block;
                block.tiles = freeblock.getMem();
                setFlag(block.flags, BlockFlags.valid, true);

                assert (block.valid);

                return block;
            }
        }
        void free(Block block) {
            synchronized(mutex) {
                freeblock.returnMem(block.tiles);
            }
        }
    }
}

Block INVALID_BLOCK = {
    tiles : null,
    flags : BlockFlags.none,
    blockNum : BlockNum(vec3i(int.min, int.min, int.min)),
};

Block AirBlock(BlockNum blockNum) {
    Block ret;
    ret.flags = cast(BlockFlags)(
            BlockFlags.valid | BlockFlags.sparse);
    ret.blockNum = blockNum;
    ret.sparseTileType = TileTypeAir;
    ret.sunLightVal = MaxLightStrength;
    return ret;
};



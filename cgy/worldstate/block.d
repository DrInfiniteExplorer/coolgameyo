
//TODO: Remove block-sparse-transparency.
//TODO: Move code for block-allocator elsewhere
//TODO: Make things private?


module worldstate.block;

import std.algorithm;
import std.exception;
import std.stdio;

import core.sync.mutex;
import core.atomic;

import light;
import util.pos;
import tiletypemanager : TileTypeAir;
//import tiletypemanager;

//import worldgen.worldgen;
import worldgen.maps;
import worldstate.tile;
import worldstate.sizes;
import util.memory;
import util.rangefromto;
import util.util;





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
        BREAK_IF(allocmap[i]);
        assert (!allocmap[i]);
        allocmap[i] = true;
        return &data[i];
    }
    void returnMem(BlockTiles* mem) {
        auto diff = mem - data.ptr;
        //writeln(mem, " ", data.ptr, " ", diff);
        //Diff is magically (cast(void*)mem - cast(void*)data.ptr) / typeof(mem).sizeof !
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

__gshared Mutex blockAllocatorMutex;
__gshared AllocationBlock* freeblock;

shared static this() {
    blockAllocatorMutex = new Mutex;
    freeblock = AllocationBlock.create();
}

shared int blockCount = 0;

ulong getBlockMemorySize() {
    return blockCount * BlockTiles.sizeof / 1024;
}

Block_t alloc() {
    Block_t block;
    block.tiles = new typeof(*block.tiles);
    setFlag(block.flags, BlockFlags.valid, true);
    blockCount = core.atomic.atomicOp!"+="(blockCount, 1);

    return block;

    /*
    synchronized(blockAllocatorMutex) {

        Block_t block;
        block.tiles = freeblock.getMem();
        setFlag(block.flags, BlockFlags.valid, true);

        assert (block.valid);

        return block;
    }
    */
}
void free(Block_t block) {
    delete block.tiles;
    blockCount = core.atomic.atomicOp!"-="(blockCount, 1);
    return;
    /*
    synchronized(blockAllocatorMutex) {
        freeblock.returnMem(block.tiles);
    }
    */
}

enum BlockFlags : ubyte {
    none                = 0,
    sparse              = 1 << 1,
    hasAir              = 1 << 2,
    hasNonAir           = 1 << 3,
    valid               = 1 << 7,
}

struct BlockTiles {
    Tile[BlockSize.x][BlockSize.y][BlockSize.z] tiles;
}

struct Block_t {

    BlockTiles* tiles = null;

    BlockFlags flags = BlockFlags.none;

    BlockNum blockNum = BlockNum(vec3i(int.min, int.min, int.min));

    ushort sparseTileType;
    byte sunLightVal;
    bool sparseTileTransparent() @property { return sparseTileType == TileTypeAir; }

    void destroy() {

        if(valid && !sparse) {
            enforce(tiles !is null, "gerp blerpo");
            free();
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
        auto a = tilePos.getBlockNum();
        auto b = this.blockNum;
        BREAK_IF(a != b);

        BREAK_IF(!valid);
        if (sparse) {
            return sparseTile();
        }
        auto pos = tilePos.rel();
        return tiles.tiles[pos.z][pos.y][pos.x];
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
        tiles.tiles[p.z][p.y][p.x] = tile;
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

        tiles.tiles[p.z][p.y][p.x].setLight(isSunLight, newVal);
    }

    bool valid() const @property { return (flags & BlockFlags.valid) != 0; }
    void valid(bool val) @property { setFlag(flags, BlockFlags.valid, val); }

    bool hasAir() const @property { return (flags & BlockFlags.hasAir) != 0; }
    void hasAir(bool val) @property { setFlag(flags, BlockFlags.hasAir, val); }

    bool hasNonAir() const @property { return (flags & BlockFlags.hasNonAir) != 0; }
    void hasNonAir(bool val) @property { setFlag(flags, BlockFlags.hasNonAir, val); }


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

    static Block_t allocBlock() {
        auto block = alloc();
        return block;
    }

    void free() {
        .free(this);
    }


    // allocation / freelist stuff
}

alias Block_t* Block;

Block_t INVALID_BLOCK = {
    tiles : null,
    flags : BlockFlags.none,
    blockNum : BlockNum(vec3i(int.min, int.min, int.min)),
};

Block_t AirBlock(BlockNum blockNum) {
    Block_t ret;
    ret.flags = cast(BlockFlags)(
            BlockFlags.valid | BlockFlags.sparse | BlockFlags.hasAir);
    ret.blockNum = blockNum;
    ret.sparseTileType = TileTypeAir;
    ret.sunLightVal = MaxLightStrength;
    return ret;
};



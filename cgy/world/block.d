
//TODO: Remove block-sparse-transparency.
//TODO: make komment for function isSame
//TODO: Move code for block-allocator elsewhere
//TODO: Make things private?


module world.block;

import std.algorithm;
import std.stdio;

import pos;
import tiletypemanager : TileTypeAir;
//import tiletypemanager;

import worldgen.worldgen;
import world.tile;
import world.sizes;
import util.util;
import util.rangefromto;




enum BlockFlags : ubyte {
    none                = 0,
    seen                = 1 << 0,
    sparse              = 1 << 1,
    valid               = 1 << 7,
}

struct Block {

    Tile[BlockSize.z][BlockSize.y][BlockSize.x]* tiles = null;

    BlockFlags flags = BlockFlags.none;

    BlockNum blockNum = BlockNum(vec3i(int.min, int.min, int.min));;

    ushort sparseTileType;
    bool sparseTileTransparent() @property { return sparseTileType == TileTypeAir; }

    invariant()
    {
        auto valid = flags & BlockFlags.valid;
        auto sparse = flags & BlockFlags.sparse;

        if (sparse) {
            assert(valid, "Block is marked as sparse, but doesn't have valid flag");
            assert(tiles is null, "Block is marked as sparse, but has tiles!");
        } else if (valid) {
            assert(tiles !is null, "Block is not sparse but valid, but doesn't have any tiles!");
        } else {
            assert(tiles is null, "Block is not valid, but has tiles!");
        }
    }

    Tile getTile(TilePos tilePos)
    in{
        assert(tilePos.getBlockNum() == this.blockNum);
    }
    body{
        assert(valid);
        if(sparse){
            Tile t;
            t.type = sparseTileType;
            t.flags = TileFlags.valid;
            t.seen = seen;
            return t;
        }
        auto pos = tilePos.rel();
        return (*tiles)[pos.X][pos.Y][pos.Z];
    }

    void setTile(TilePos pos, Tile tile)
    in{
        assert(pos.getBlockNum() == this.blockNum);
    }
    body{
        assert(valid);
        auto p = pos.rel();

        if(sparse){ //If was sparse, populate with real tiles
            auto block = alloc();
            tiles = block.tiles;
            setFlag(flags, BlockFlags.sparse, false);

            Tile t;
            t.type = sparseTileType;
            t.flags = TileFlags.valid;
            t.seen = seen;
            (*(cast(Tile[BlockSize.x*BlockSize.y*BlockSize.z]*)(tiles)))[] = t; //Fuck yeah!!!! ? :S:S:S
        }
        (*tiles)[p.X][p.Y][p.Z] = tile;
    }

    void setTileLight(TilePos pos, const byte newVal, const bool isSunLight)
    in{
        assert(pos.getBlockNum() == this.blockNum);
    }
    body{
        assert(valid);
        auto p = pos.rel();

        if(sparse){ //If was sparse, populate with real tiles
            auto block = alloc();
            tiles = block.tiles;
            setFlag(flags, BlockFlags.sparse, false);

            Tile t;
            t.type = sparseTileType;
            t.flags = TileFlags.valid;
            t.seen = seen;
            (*(cast(Tile[BlockSize.x*BlockSize.y*BlockSize.z]*)(tiles)))[] = t; //Fuck yeah!!!! ? :S:S:S
        }
        if(isSunLight) {
            (*tiles)[p.X][p.Y][p.Z].sunLightValue = newVal;
        } else {
            (*tiles)[p.X][p.Y][p.Z].lightValue = newVal;
        }
    }

    bool isSame(const Block other) const {
        //TODO: Need comment detailing the logic behind this.
        return blockNum == other.blockNum && (sparse || tiles is other.tiles);
    }

    bool valid() const @property { return (flags & BlockFlags.valid) != 0; }
    void valid(bool val) @property { setFlag(flags, BlockFlags.valid, val); }

    bool seen() const @property { return (flags & BlockFlags.seen) != 0; }
    void seen(bool val) @property { setFlag(flags, BlockFlags.seen, val); }

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
        } else {
            BREAK_IF(tiles is null);            
            write((&((*tiles)[0][0][0]))[0 .. BlockSize.x * BlockSize.y * BlockSize.z]);
        }
    }
    
    void deserialize(void delegate(size_t size, ubyte* buff) read) {
        read(blockNum.sizeof, cast(ubyte*)&blockNum);
        read(flags.sizeof, cast(ubyte*)&flags);
        if ((flags & BlockFlags.sparse) != 0) {
            read(sparseTileType.sizeof, cast(ubyte*)&sparseTileType);
        } else {
            auto block = alloc();
            block.flags = flags;
            block.blockNum = blockNum;
            static assert(BlockSize.x * BlockSize.y * BlockSize.z * Tile.sizeof == (*tiles).sizeof);
            read((*tiles).sizeof, cast(ubyte*)block.tiles.ptr);
            this = block;
        }
    }

    static Block generateBlock(BlockNum blockNum, WorldGenerator worldgen) {
        //msg("Generating block: ", blockNum);
        auto block = alloc();
        block.blockNum = blockNum;
        
        //BREAKPOINT(blockNum.value == vec3i(13, 32, 1));

        bool homogenous = true;
        bool first = true;

        foreach (relPos; RangeFromTo (0, BlockSize.x-1,
                    0, BlockSize.y-1, 0, BlockSize.z-1)) {
            auto TP = blockNum.toTilePos();
            TP.value += relPos;
            auto tile = worldgen.getTile(TP);
            (*block.tiles)[relPos.X][relPos.Y][relPos.Z] = tile;

            if (first) {
                first = false;
                block.sparseTileType = tile.type;
            }
            if (block.sparseTileType != tile.type) {
                homogenous = false;
            }
        }
        if (homogenous) {
            free(block);
            block.tiles = null;
            setFlag(block.flags, BlockFlags.sparse, true);
        }
        return block;
    }


    // allocation / freelist stuff

    private static {
        struct AllocationBlock {
            alias Tile[BlockSize.z][BlockSize.y][BlockSize.x] T;
            bool[] allocmap; // true = allocated, false = not
            T[] data;

            //static assert (T.sizeof == 4096);

            enum dataSize = 128;

            AllocationBlock* next;

            T* getMem() {
                auto i = allocmap.countUntil(false);
                if (i < 0) {
                    if (next is null) next = create();
                    return next.getMem();
                }
                assert (!allocmap[i]);
                allocmap[i] = true;
                return &data[i];
            }
            void returnMem(T* mem) {
                auto diff = mem - data.ptr;
                if (0 <= diff && diff < dataSize) {
                    // IT IS OUR BLOB!!!!!
                    allocmap[diff] = false;
                } else {
                    assert (next, "We have our buddie's blob, "~
                            "but our buddy is dead. Gosh darned it!");
                    next.returnMem(mem);
                }
            }

            static AllocationBlock* create() {
                auto alloc = new AllocationBlock;
                alloc.allocmap = new bool[](dataSize);
                auto blob = allocateBlob(dataSize, T.sizeof);
                (cast(ubyte[])blob)[] = 0;
                alloc.data = cast(T[])blob;
                return alloc;
            }
        }
        AllocationBlock* freeblock;

        Block alloc() {
            if (freeblock is null) {
                freeblock = AllocationBlock.create();
            }

            Block block;
            block.tiles = freeblock.getMem();
            setFlag(block.flags, BlockFlags.valid, true);

            assert (block.valid);

            return block;
        }
        void free(Block block) {
            freeblock.returnMem(block.tiles);
        }
    }
}

Block INVALID_BLOCK = {
    tiles : null,
    flags : BlockFlags.none,
    blockNum : BlockNum(vec3i(int.min, int.min, int.min)),
};

Block AirBlock(BlockNum blockNum) {
    Block ret = Block();
    ret.flags = cast(BlockFlags)(BlockFlags.valid | BlockFlags.sparse);
    ret.blockNum = blockNum;
    ret.sparseTileType = TileTypeAir;
    return ret;
};



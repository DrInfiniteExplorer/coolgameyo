
module worldparts.block;

import std.algorithm;

import worldparts.tile;
import pos;
import worldgen;
import util;

enum BlockSize {
    x = 8,
    y = 8,
    z = 8,
    total = x*y*z
}

alias BlockSize TilesPerBlock;

enum BlockFlags : ubyte {
    none                = 0,
    seen                = 1 << 0,
    sparse              = 1 << 1,
    sparse_transparent  = 1 << 2,
    dirty               = 1 << 6,
    valid               = 1 << 7,
}

struct Block {

    struct RenderData {
        ushort idxCnt;
        uint[2] VBO;
    }

    Tile[BlockSize.z][BlockSize.y][BlockSize.x]* tiles = null;

    BlockFlags flags = BlockFlags.none;

    RenderData renderData;

    BlockNum blockNum;

    ushort sparseTileType;
    bool sparseTileTransparent() @property { return 0!=(flags & BlockFlags.sparse_transparent); }
    void sparseTileTransparent(bool flag) @property { setFlag(flags, BlockFlags.sparse_transparent, flag); }
    
    invariant()
    {
        bool valid = (flags & BlockFlags.valid)!=0;
        bool sparse = (flags & BlockFlags.sparse)!=0;
        
        if(sparse){
            assert(valid, "Block is marked as sparse, but doesn't have valid flag");
            assert(tiles is null, "Block is marked as sparse, but has tiles!");
        }
        else if(valid){
            assert(tiles !is null, "Block is not sparse but valid, but doesn't have any tiles!");
        }
        else{
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
            t.transparent = sparseTileTransparent;
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

        auto same = (*tiles)[p.X][p.Y][p.Z] == tile;
        if(!same){
            dirty = true;
            if(sparse){ //If was sparse, populate with real tiles
                Tile t;
                t.type = sparseTileType;
                t.flags = TileFlags.valid;
                t.seen = seen;
                t.transparent = sparseTileTransparent;
                (*(cast(Tile[BlockSize.x*BlockSize.y*BlockSize.z]*)(tiles)))[] = t; //Fuck yeah!!!! ? :S:S:S
                sparse = false;
            }
        }
        (*tiles)[p.X][p.Y][p.Z] = tile;
    }

    bool isSame(const Block other) const {
        return blockNum == other.blockNum && (sparse || tiles is other.tiles);
    }
    
    bool valid() const @property { return (flags & BlockFlags.valid) != 0; }
    void valid(bool val) @property { setFlag(flags, BlockFlags.valid, val); }

    bool seen() const @property { return (flags & BlockFlags.seen) != 0; }
    void seen(bool val) @property { setFlag(flags, BlockFlags.seen, val); }

    bool sparse() const @property { return (flags & BlockFlags.sparse) != 0; }
    void sparse(bool val) @property { setFlag(flags, BlockFlags.sparse, val); }

    bool dirty() const @property { return (flags & BlockFlags.dirty) != 0; }
    void dirty(bool val) @property { setFlag(flags, BlockFlags.dirty, val); }

    void clean(ushort idxCnt) {
        dirty = false;
        renderData.idxCnt = idxCnt;
    }
    

    static Block generateBlock(BlockNum blockNum, WorldGenerator worldgen) {
        //writeln("Generating block: ", blockNum);
        auto block = alloc(); //Derp derp?
        block.blockNum = blockNum;
        //block.valid = true; Comes valid from alloc().
        block.dirty = true;
        
        bool homogenous = true;
        block.sparseTileType = TileTypeInvalid;
        foreach (relPos; RangeFromTo(0, BlockSize.x, 
                    0, BlockSize.y, 0, BlockSize.z)) {
            auto TP = blockNum.toTilePos();
            TP.value += relPos;
            auto tile = worldgen.getTile(TP);
            (*block.tiles)[relPos.X][relPos.Y][relPos.Z] = tile;
            
            if (block.sparseTileType == TileTypeInvalid) {
                block.sparseTileType = tile.type;
                block.sparseTileTransparent = tile.transparent; //Copy transparency-property from first tile.
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

            static assert (T.sizeof == 4096);

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
                //alloc.data = allocateBlob(dataSize);
                alloc.data = cast(typeof(alloc.data))(allocateBlob(dataSize));
                
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

            return block;
        }
        void free(Block block) {
            freeblock.returnMem(block.tiles);
        }
    }
}

Block INVALID_BLOCK = {
    tiles :null,
    flags : BlockFlags.none,
    renderData : Block.RenderData(0,[0,0]),
    blockNum : blockNum(vec3i(int.min, int.min, int.min)),
    sparseTileType : TileTypeInvalid
};



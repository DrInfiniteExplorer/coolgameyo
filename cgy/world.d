import std.algorithm, std.range, std.stdio;
import std.container;
import std.exception;

import engine.irrlicht;

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
    }

    void generateBlock(BlockNum blockNum) {
        //Was toSectorPos insted of getSectorNumber which i'm guessing it's supposed to be.
        //Discovered after fixing this that getSector takes a tilepos and internally uses
        // "toSectorPos" ie. getSectorNumber. So removing that call here.
        auto sector = getSector(blockNum.getSectorNum());
        sector.generateBlock(blockNum, worldGen); 
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
        
        foreach(relPos ; RangeFromTo(0, SectorSize.x, 0, SectorSize.y, 0, 1)){            
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
            auto ret = getSectorXY(xy);;
            sectorXY[xy] = ret;
        }

        auto sector = new Sector(sectorNum);
        assert(sector !is null, "derp!");

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
        auto sector = getSector(blockNum.getSectorNum());
        sector.setBlock(blockNum, newBlock);
    }

    Sector[] lock() { return sectorList; }

    void addUnit(Unit* unit) {
        unitCount += 1;
        auto sectorNum = unit.tilePosition.getSectorNum();
        auto sector = getSector(sectorNum);
        sector.addUnit(unit);
        
        //Range +-2
        
        auto range = RangeFromTo(-2,3,-2,3,-2,3);
        //debug
        {
            range = RangeFromTo(0,1,0,1,0,1); //Make it faster in debyyyyg!!
        }
                
        foreach (dpos; range) {
            auto pos = unit.tilePosition.getSectorNum();
            pos.value.X +=  dpos.X;
            pos.value.Y +=  dpos.Y;
            pos.value.Z +=  dpos.Z;
            getSector(pos).increaseActivity();
        }
    }

    Tile getTile(TilePos tilePos, bool createBlock=true,
                                  bool createSector=true) {
        auto block = getBlock(tilePos.getBlockNum(), createBlock, createSector);
        if(!block.valid){
            return INVALID_TILE;
        }
        return block.getTile(tilePos);
    }
    void setTile(TilePos tilePos, const Tile newTile) {
        getBlock(tilePos.getBlockNum()).setTile(tilePos, newTile);
        notifyTileChange(tilePos);
    }

    TilePos getTopTilePos(TileXYPos xy) {
        auto rel = xy.sectorRel();
        auto x = rel.X;
        auto y = rel.Y;

        auto t = xy.getSectorXYNum();
        auto sectorXY = getSectorXY(t);
        
        auto heightmapPtr = sectorXY.heightmap;
        assert(heightmapPtr !is null, "heightmapPtr == null! :(");
        auto pos = vec3i(x, y, (*heightmapPtr)[x][y]);
        return tilePos(pos);        
    }
    
    /* Only used when like, spawning first units? */
    /* After that, when a unit moves, it is checked if the unit is interesting, */
    /* and if it moves outside of (interestingMin, interesingMax)+-padding (which are sectornums) */
    /*  */
    /* Still, how to properly do floodfill in caves et c? */
    void calculateInterestingRegion(){
        auto box = aabbox3d!(int)(int.max, int.max, int.max, int.min, int.min, int.min);
        foreach(sector ; sectorList){
            foreach(unit; sector.units){
                box.addInternalPoint(unit.pos);
            }
        }
        auto paddingSize = vec3i(0, 0, 0);
        auto sectorNumMax = tilePos(box.MaxEdge).getSectorNum();
        auto sectorNumMin = tilePos(box.MinEdge).getSectorNum();
        sectorNumMax.value += paddingSize;
        sectorNumMin.value -= paddingSize;

        SectorNum[] newSectors;
        foreach(pos; RangeFromTo(sectorNumMin.value, sectorNumMax.value+vec3i(1,1,1))){
            auto secNum = sectorNum(pos);
            auto sector = getSector(secNum, false);
            if(sector is null){
                sector = getSector(secNum);
                newSectors ~= secNum;
            }
        }
        
        foreach(sectorNum; newSectors){
            auto xy = sectorNum.toTilePos().toTileXYPos();
            floodFillVisibility(xy);
        }
        foreach(sectorNum; newSectors){
            notifySectorLoad(sectorNum);
        }
        
    }

    void floodFillVisibility(const TileXYPos xyStart) {
        auto startPos = getTopTilePos(xyStart);
        startPos.value += vec3i(0,0,1);

        RedBlackTree!(BlockNum, q{a.value < b.value}) work;        
        
        //work.insert(startPos.getBlockNum()); //Retardedly retarded redblacktree needs to be initialized with something.
        work = typeof(work)(startPos.getBlockNum());

        int allBlocks = 0;
        int blockCount = 0;
        int sparseCount = 0;
        while (!work.empty) {
            auto blockNum = work.removeAny();            

            auto block = getBlock(blockNum);
            if(block.seen) { continue; }
            allBlocks++;
            if (!block.valid) { continue; }
            
            //writeln("\tFlooding block ", blockNum);
            
            blockCount++;
            //writeln("blockCount:", blockCount);
            auto blockPos = blockNum.toTilePos();

            block.seen = true;

            scope (exit) setBlock(blockNum, block);

            if (block.sparse) {
                sparseCount++;
                if (block.type == TileType.air) {
                    work.insert(.blockNum(blockNum.value + vec3i(1, 0, 0)));
                    work.insert(.blockNum(blockNum.value - vec3i(1, 0, 0)));
                    work.insert(.blockNum(blockNum.value + vec3i(0, 1, 0)));
                    work.insert(.blockNum(blockNum.value - vec3i(0, 1, 0)));
                    work.insert(.blockNum(blockNum.value + vec3i(0, 0, 1)));
                    work.insert(.blockNum(blockNum.value - vec3i(0, 0, 1)));
                } else {
                    switch(block.type){
                        case TileType.retardium:
                            break;
                        default:
                            assert (0, "Sparse block of unknown type encountered");
                    }
                }
                continue;
            }
            
            foreach (rel; 
                    RangeFromTo(0,BlockSize.x,0,BlockSize.y,0,BlockSize.z)) {
                auto tp = tilePos(blockPos.value + rel);
                auto tile = block.getTile(tp);

                scope (exit) block.setTile(tp, tile);

                if (tile.type == TileType.air) {
                    tile.seen = true;
                    if (rel.X == 0) {
                        work.insert(.blockNum(blockNum.value - vec3i(1,0,0)));
                    } else if (rel.X == BlockSize.x - 1) {
                        work.insert(.blockNum(blockNum.value + vec3i(1,0,0)));
                    }
                    if (rel.Y == 0) {
                        work.insert(.blockNum(blockNum.value - vec3i(0,1,0)));
                    } else if (rel.Y == BlockSize.y - 1) {
                        work.insert(.blockNum(blockNum.value + vec3i(0,1,0)));
                    }
                    if (rel.Z == 0) {
                        work.insert(.blockNum(blockNum.value - vec3i(0,0,1)));
                    } else if (rel.Z == BlockSize.z - 1) {
                        work.insert(.blockNum(blockNum.value + vec3i(0,0,1)));
                    }
                } else {
                    foreach (npos; neighbors(tp)) {
                        auto neighbor = getTile(npos, true, false);
                        if (neighbor.valid && neighbor.type == TileType.air) {
                            tile.seen = true;
                            break;
                        }
                    }
                }
            }
        }
        writeln("allBlocks");
        writeln(allBlocks);
        writeln("blockCount");
        writeln(blockCount);
        writeln("sparseCount");
        writeln(sparseCount);
    }


    void addListener(WorldListener listener) {
        listeners ~= listener;
    }
    void removeListener(WorldListener listener) {
        remove(listeners, countUntil!q{a is b}(listeners, listener));
        listeners.length -= 1;
    }
    
    //To be called... WHEEEEN?
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
    
    invariant(){
        assert(sectorNum.toTilePos() == pos);
        assert(pos.getSectorNum() == sectorNum);
    }
    
    int blockCount;

    Block[BlocksPerSector.z][BlocksPerSector.y][BlocksPerSector.x] blocks;
    static assert(blocks.length == BlocksPerSector.x);
    

    RedBlackTree!(Unit*) units;
    int activityCount;

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

alias BlockSize TilesPerBlock;

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

    Tile[BlockSize.z][BlockSize.y][BlockSize.x]* tiles = null;

    BlockFlags flags = BlockFlags.none;

    RenderData renderData;

    BlockNum blockNum;

    TileType type;
    
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
            t.type = type;
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

        auto same = (*tiles)[p.X][p.Y][p.Z] == tile;
        if(!same){
            dirty = true;
            if(sparse){ //If was sparse, populate with real tiles
                Tile t;
                t.type = type;
                t.flags = TileFlags.valid;
                t.seen = seen;
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
        block.type = TileType.invalid;
        foreach (relPos; RangeFromTo(0, BlockSize.x, 
                    0, BlockSize.y, 0, BlockSize.z)) {
            auto TP = blockNum.toTilePos();
            TP.value += relPos;
            auto tile = worldgen.getTile(TP);
            (*block.tiles)[relPos.X][relPos.Y][relPos.Z] = tile;
            
            if (block.type == TileType.invalid) {
                block.type = tile.type;
            }
            if (block.type != tile.type) {
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
    TileType type = TileType.invalid;
    TileFlags flags = TileFlags.none;
    ushort hp = 0;
    ushort textureTile = 0;
    
    bool valid() const @property { return (flags & TileFlags.valid) != 0; }
    void valid(bool val) @property { setFlag(flags, TileFlags.valid, val); }

    bool seen() const @property { return (flags & TileFlags.seen) != 0; }
    void seen(bool val) @property { setFlag(flags, TileFlags.seen, val); }
    
    
    bool transparent() const @property{
        switch(type){
            case TileType.invalid:
            case TileType.air:
                return true;
            default:
                return false;
        }
    }
}

enum INVALID_TILE = Tile(TileType.invalid, TileFlags.none, 0, 0);


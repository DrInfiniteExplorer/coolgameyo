//TODO: Lots of stuff
//TODO: make members private etc


module worldparts.sector;

import std.algorithm;
import std.conv;
import std.container;
import std.exception;
import std.file;
import std.range;
import std.stdio;

import json;
import worldparts.block;
import worldgen.worldgen;
import pos;
import unit;
import entity;
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

    private TilePos pos;
    private SectorNum sectorNum;

    private Block[BlocksPerSector.z][BlocksPerSector.y][BlocksPerSector.x] blocks;
    static assert(blocks.length == BlocksPerSector.x);

    RedBlackTree!(Unit*) units; //TODO: how to make this private without breaking stuff derp? :S
	RedBlackTree!(Entity*) entities;
    private int activityCount;

    invariant(){
        ASSERT(sectorNum.toTilePos() == pos);
        ASSERT(pos.getSectorNum() == sectorNum);
        ASSERT(activityCount >= 0);
    }

    this(SectorNum sectorNum_) {
        sectorNum = sectorNum_;
        pos = sectorNum.toTilePos();
        units = new typeof(units);
		entities = new typeof(entities);
    }

    const(Block)[] getBlocks() const {
        debug {
            auto b = &blocks[0][0][0];
            auto bb = b[0 .. BlocksPerSector.total];
            assert (&bb[0] is &blocks[0][0][0]);
            assert (&bb[$-1] is &blocks[$-1][$-1][$-1]);
        }

        return (&blocks[0][0][0])[0 .. BlocksPerSector.total];
    }
    
    void serialize() {
        string folder = text("saves/current/world/", sectorNum.value.X, ",", sectorNum.value.Y, "/", sectorNum.value.Z, "/");
        mkdirRecurse(folder);
        
        auto file = std.stdio.File(folder ~ "blocks.bin", "wb");
        
        void write(const void[] buff) {
            file.rawWrite(buff);
        }
        
        foreach( block ; (&blocks[0][0][0])[0 .. BlocksPerSector.total]) {
            if (!block.valid) continue;
            block.serialize(&write);
        }
        file.close();
        
        int asd[] = [activityCount];
        std.file.write(folder ~ "activityCount", asd);
        
        Value derp(Unit* unit) {
            return encode(*unit);
        }
        Value jsonRoot = Value(array(map!derp(array(units))));
        auto jsonString = to!string(jsonRoot);	
	    jsonString = json.prettyfyJSON(jsonString);
        std.file.write(folder ~ "units.json", jsonString);

        Value darp(Entity* entity) {
            return encode(*entity);
        }
        jsonRoot = Value(array(map!darp(array(entities))));
        jsonString = to!string(jsonRoot);	
	    jsonString = json.prettyfyJSON(jsonString);
        std.file.write(folder ~ "entities.json", jsonString);
    }
    
    bool deserialize() {
        string folder = text("saves/current/world/", sectorNum.value.X, ",", sectorNum.value.Y, "/", sectorNum.value.Z, "/");
        if (!exists(folder)) {
            return false;
        }
        auto file = std.stdio.File(folder ~ "blocks.bin", "rb");
        
        ulong readBytes = 0;
        ulong fileSize = file.size();
        void read(size_t amount, ubyte* buff) {
            enforce(readBytes + amount <= fileSize, "Error, trying to read more data from a file than there is!");
            readBytes += amount;
            auto herp = buff[0 .. amount];
            enforce( file.rawRead(herp) !is null, "Failed reading block!");
        }

        while (readBytes < fileSize) {
            Block block;
            block.deserialize(&read);
            auto num = block.blockNum.rel();
            blocks[num.X][num.Y][num.Z] = block;
        }
        file.close();
        
        int asd[] = cast(int[])std.file.read(folder ~ "activityCount");
        activityCount = asd[0];
        
        auto content = readText(folder ~ "units.json");
        auto jsonRoot = json.parse(content);
        foreach (unitVal ; jsonRoot.elements) {
            Unit* unit = new Unit;
            unit.fromJSON(unitVal);
            units.insert(unit);
        }
        
		// Todo: remove this whenever everyone has renamed their saves
		if(!std.file.exists(folder ~ "entities.json")){
			content = readText(folder ~ "objects.json");
		}
        else{
			content = readText(folder ~ "entities.json");
		}
        jsonRoot = json.parse(content);
        foreach (entityVal ; jsonRoot.elements) {
            Entity* entity = new Entity;
            entity.fromJSON(entityVal);
            entities.insert(entity);
        }
        return true;
    }
    

    //TODO: What about if there already was a block there?
    //   potential solution; use setBlock ?
    void generateBlock(BlockNum blockNum, WorldGenerator worldGen)
    in{
        assert(blockNum.getSectorNum() == sectorNum, "Trying to generate a block in the wrong sector!");
        assert(blockNum.getSectorNum.toTilePos() == pos); //Good to have? In that case, add to other places like getBlock() as well.
        auto pos = blockNum.rel();
//        auto block = blocks[pos.X][pos.Y][pos.Z];
//        writeln("! ", block.tiles, " ", cast(int)block.flags, " ", block.blockNum, " ", block.sparseTileType);
        assert(blocks[pos.X][pos.Y][pos.Z] == INVALID_BLOCK, text("Trying to generate a block which already contains stuff.", blockNum));
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
                msg("Make fix this");
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
	void addEntity(Entity* o) {
        entities.insert(o);
    }
    
    SectorNum getSectorNum() const @property { return sectorNum; }
    
    int activity() const @property { return activityCount; }
    void increaseActivity() { activityCount += 1; }
    void decreaseActivity() { activityCount -= 1; }
}


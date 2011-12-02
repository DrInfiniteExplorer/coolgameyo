//TODO: Lots of stuff
//TODO: make members private etc


module world.sector;

import std.algorithm;
import std.conv;
import std.container;
import std.exception;
import std.file;
import std.range;
import std.stdio;

import entitytypemanager;
import json;
import light;
import world.world;
import world.block;
import world.sizes;
import worldgen.worldgen;
import pos;
import unit;
import entity;
import util.util;
import util.intersect;
import util.filesystem;
import util.rangefromto;



enum PackInInt = true;
static if(PackInInt) {
    enum BitCount = 32;
    alias uint StorageType;
} else {
    enum BitCount = 8;
    alias ubyte StorageType;
}

struct SolidMap {
    const int sizeX = SectorSize.x / BitCount;
    const int sizeY = SectorSize.y;
    const int sizeZ = SectorSize.z;
    StorageType[sizeX][sizeY][sizeZ] data;
    bool dirty = false;

    bool set(vec3i idx, bool val) {
        int x   = idx.X/BitCount;
        int bit = idx.X%BitCount;
        int y   = idx.Y;
        int z   = idx.Z;

        StorageType value = data[z][y][x];
        StorageType bitMask = cast(StorageType)(1<<bit);
        bool oldVal = (value & bitMask) != 0;
        setFlag(value, bitMask, val);
        data[z][y][x] = value;
        dirty |= (oldVal != val);
        return oldVal;
    }
    bool get(vec3i idx) const {
        int x   = idx.X/BitCount;
        int bit = idx.X%BitCount;
        int y   = idx.Y;
        int z   = idx.Z;

        return 0 != (data[z][y][x] & (1<<bit));
    }

    void clear() {
        dirty=true;
        (&data[0][0][0])[0..(data.sizeof / data[0][0][0].sizeof)] = 0;
    }
    void fill() {
        dirty=true;
        (&data[0][0][0])[0..(data.sizeof / data[0][0][0].sizeof)] = 0xFF;
    }

    void updateBlock(Block b) {
        dirty=true;
        auto blockNum = b.blockNum;
        auto relNum = blockNum.rel();
        auto blockTilePos = blockNum.toTilePos();
        int x = relNum.X * BlockSize.x;
        int y = relNum.Y * BlockSize.y;
        int z = relNum.Z * BlockSize.z;


        foreach(rel ; RangeFromTo(vec3i(0), vec3i(BlockSize.x-1, BlockSize.y-1, BlockSize.z-1))) {
            int xx = x + rel.X;
            int yy = y + rel.Y;
            int zz = z + rel.Z;
            set(vec3i(xx, yy, zz), !b.getTile(TilePos(blockTilePos.value + rel)).isAir);
        }
    }


    bool hasContent(vec3i relMin, vec3i relMax) {
        //TODO: Optimize this with kewl functions that counts/finds first set bit.
        foreach( pos ; RangeFromTo(relMin, relMax)) {
            if(get(pos)) {
                return true;
            }
        }
        return false;
    }

}
static assert(SolidMap.data.sizeof == 65536); //64k yeah :)

class Sector {

    private TilePos pos;
    private SectorNum sectorNum;

    private Block[BlocksPerSector.z][BlocksPerSector.y][BlocksPerSector.x] blocks;
    static assert(blocks.length == BlocksPerSector.x);

    private SolidMap solidMap;


    RedBlackTree!(Unit*) units; //TODO: how to make this private without breaking stuff derp? :S
	RedBlackTree!(Entity) entities;
    private int activityCount;

    invariant(){
        BREAK_IF(sectorNum.toTilePos() != pos);
        BREAK_IF(pos.getSectorNum() != sectorNum);
        BREAK_IF(activityCount < 0);
    }

    this(SectorNum sectorNum_) {
        sectorNum = sectorNum_;
        pos = sectorNum.toTilePos();
        units = new typeof(units);
		entities = new typeof(entities);
        solidMap.clear;
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
        util.filesystem.mkdir(folder);
        
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
	    auto jsonString = json.prettifyJSON(jsonRoot);
        std.file.write(folder ~ "units.json", jsonString);

        Value darp(Entity entity) {
            return encode(entity);
        }
        jsonRoot = Value(array(map!darp(array(entities))));
	    jsonString = json.prettifyJSON(jsonRoot);
        std.file.write(folder ~ "entities.json", jsonString);
    }
    
    bool deserialize(EntityTypeManager entityTypeManager, World world) {
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
            solidMap.updateBlock(block);
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
            Entity entity = newEntity();
            entity.fromJSON(entityVal, entityTypeManager);
            entities.insert(entity);
            world.addLightFromEntity(entity);
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
        auto block = Block.generateBlock(blockNum, worldGen);
        blocks[pos.X][pos.Y][pos.Z] = block;
        solidMap.updateBlock(block);
    }

    void makeAirBlock(BlockNum blockNum) {
        auto pos = blockNum.rel();
        auto airBlock = AirBlock(blockNum);
        blocks[pos.X][pos.Y][pos.Z] = airBlock;
        //No need to update solidmap; will be clear from beginning, and only call this during worldgen anyway.
    }

    Block* getBlock(BlockNum blockNum)
    in{
        assert(blockNum.getSectorNum() == sectorNum);
    }
    body{
        auto pos = blockNum.rel();
        return &blocks[pos.X][pos.Y][pos.Z];
    }

    void setBlock(BlockNum blockNum, Block newBlock)
    in {
        assert(blockNum.getSectorNum() == sectorNum, "Sector.setBlock: Trying to set a block that doesn't belong here!");
    }
    body {
        enforce(false, "We dont support setting blocks anylonger. See http://luben.se/wiki/index.php?page=Tilerepresentation");
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
        solidMap.updateBlock(newBlock);
    }

    bool hasContent(TilePos min, TilePos max) {
        auto relMin = min.sectorRel();
        auto relMax = max.sectorRel();
        return solidMap.hasContent(relMin, relMax);
    }

    //Returns old solidnessvalue
    bool setSolid(TilePos tilePos, bool solid) { 
        auto sectorRel = tilePos.sectorRel;
        return solidMap.set(sectorRel, solid);
    }
    bool isSolid(TilePos tilePos) const {
        auto sectorRel = tilePos.sectorRel;
        return solidMap.get(sectorRel);
    }
    SolidMap* getSolidMap() {
        return &solidMap;
    }

    //TODO: Add more unit-interfacing etc.
    void addUnit(Unit* u) {
        units.insert(u);
    }
	void addEntity(Entity o) {
        entities.insert(o);
    }
	void removeUnit(Unit* u) {
        units.removeKey(u);
    }
	void removeEntity(Entity o) {
        entities.removeKey(o);
    }
    
    SectorNum getSectorNum() const @property { return sectorNum; }
    
    int activity() const @property { return activityCount; }
    void increaseActivity() { activityCount += 1; }
    void decreaseActivity() { activityCount -= 1; }

    LightSource[] lights;
    void addLight(LightSource light)
    in{
        foreach(l; lights) {
            assert(l !is light, "Dont add the same light multiple times!");
        }
    }
    body{
        lights ~= light; 
    }

    void removeLight(LightSource light) {
        lights = remove(lights, countUntil!"a is b"(lights, light));
    }

    LightSource[] getLightsWithin(TilePos min, TilePos max) {
        LightSource[] ret;
        foreach(light ; lights ) {
            vec3i lightPos = light.position.tilePos.value;
            if(within(lightPos, min.value, max.value)) {
                ret ~= light;
            }
        }
        return ret;
    }
}


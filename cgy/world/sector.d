//TODO: Lots of stuff
//TODO: make members private etc


module world.sector;

import std.algorithm;
import std.conv;
import std.container;
import std.exception;
//import std.file;
import std.range;
import std.stdio;

import entitytypemanager;
import json;
import light;
import world.world;
import world.block;
import world.sizes;
//import worldgen.worldgen;
import worldgen.newgen;
import pos;
import unit;
import entities.entity;
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


    //These are just cross-references.
    //At the moment they are not updated when units change sectors :P
    Unit[] units; //TODO: how to make this private without breaking stuff derp? :S
	Entity[] entities;

    invariant(){
        BREAK_IF(sectorNum.toTilePos() != pos);
        BREAK_IF(pos.getSectorNum() != sectorNum);
    }

    this(SectorNum sectorNum_) {
        sectorNum = sectorNum_;
        pos = sectorNum.toTilePos();
        solidMap.clear;
    }


    bool destroyed = false;
    ~this() {
        //BREAK_IF(!destroyed);
        msg("Sector destructor called: "); //, sectorNum);
    }

    void destroy() {
        msg("Destroying sector ", sectorNum);
        foreach(ref block ; (&blocks[0][0][0])[0 .. BlocksPerSector.total]) {
            block.destroy();
        }
        destroyed = true;
        msg("Done destroying");
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
        
        Value jsonRoot = encode(array(map!q{a.unitId}(array(units))));
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
        if (!std.file.exists(folder)) {
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
            enforce(blocks[num.X][num.Y][num.Z].tiles is null, "DERP!");
            blocks[num.X][num.Y][num.Z] = block;
            solidMap.updateBlock(block);
            block.tiles = null;
        }
        file.close();
                
        auto content = readText(folder ~ "units.json");
        auto jsonRoot = json.parse(content);
        foreach (unitVal ; jsonRoot.elements) {
//            Unit unit = new Unit;
//            unit.fromJSON(unitVal);
//            units.insert(unit);
            int unitId;
            json.read(unitId, unitVal);
            addUnit(world.getUnitById(unitId));
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
            //Entity entity = newEntity();
            //entity.fromJSON(entityVal, entityTypeManager);
            //addEntity(entity);
            //world.addLightFromEntity(entity);
        }
        return true;
    }
    
    void generateBlock(BlockNum blockNum, WorldGenerator worldGen)
    in{
        assert(blockNum.getSectorNum() == sectorNum, "Trying to generate a block in the wrong sector!");
        assert(blockNum.getSectorNum.toTilePos() == pos);
        auto pos = blockNum.rel();
        assert(blocks[pos.X][pos.Y][pos.Z] == INVALID_BLOCK, 
                text("Trying to generate a block which already contains stuff.",
                    blockNum));
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
    }

    Block* getBlock(BlockNum blockNum)
    in{
        assert(blockNum.getSectorNum() == sectorNum);
    }
    body{
        auto pos = blockNum.rel();
        return &blocks[pos.X][pos.Y][pos.Z];
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
    void addUnit(Unit u) {
        units ~= u;
    }
    void addEntity(Entity o) {
        entities ~= o;
    }
    void removeUnit(Unit u) {
        bool pred(Unit a) { return a == u; }
        units = remove!pred(units);
    }
    void removeEntity(Entity o) {
        bool pred(Entity a) { return a == o; }
        entities = remove!pred(entities);
    }
    
    SectorNum getSectorNum() const @property { return sectorNum; }
    
    LightSource[] lights;
    void addLight(LightSource light) {
        assert (!lights.canFind!"a is b"(light),
                "Dont add the same light multiple times!");
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


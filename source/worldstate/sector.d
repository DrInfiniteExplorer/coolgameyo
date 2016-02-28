//TODO: Lots of stuff
//TODO: make members private etc


module worldstate.sector;

import std.algorithm;
import std.conv;
import std.exception;
//import std.file;
import std.range;
import std.stdio;

import clans;
import entitytypemanager;
import light;
import globals : g_worldPath;
import worldgen.maps;
import worldstate.worldstate;
import worldstate.block;
import cgy.util.sizes;
//import worldgen.worldgen;
import cgy.util.pos;
import unit;
import entities.entity;
import cgy.util.util;
import cgy.util.intersect;
import cgy.util.filesystem;
import cgy.util.rangefromto;



immutable BitCount = 32;
alias uint StorageType;

struct SolidMap {
    static immutable int sizeX = SectorSize.x / BitCount;
    static immutable int sizeY = SectorSize.y;
    static immutable int sizeZ = SectorSize.z;
    StorageType[sizeX][sizeY][sizeZ] data;

    bool dirty = false;

    bool set(vec3i idx, bool val) {
        int x   = idx.x/BitCount;
        int bit = idx.x%BitCount;
        int y   = idx.y;
        int z   = idx.z;

        StorageType value = data[z][y][x];
        StorageType bitMask = cast(StorageType)(1<<bit);
        bool oldVal = (value & bitMask) != 0;
        setFlag(value, bitMask, val);
        data[z][y][x] = value;
        dirty |= (oldVal != val);
        return oldVal;
    }
    bool get(vec3i idx) const {
        int x   = idx.x/BitCount;
        int bit = idx.x%BitCount;
        int y   = idx.y;
        int z   = idx.z;

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

    void updateBlock(Block_t b) {
        dirty=true;
        auto blockNum = b.blockNum;
        auto relNum = blockNum.rel();
        auto blockTilePos = blockNum.toTilePos();
        int x = relNum.x * BlockSize.x;
        int y = relNum.y * BlockSize.y;
        int z = relNum.z * BlockSize.z;


        foreach(rel ; RangeFromTo(vec3i(0), vec3i(BlockSize.x-1, BlockSize.y-1, BlockSize.z-1))) {
            int xx = x + rel.x;
            int yy = y + rel.y;
            int zz = z + rel.z;
            set(vec3i(xx, yy, zz), !b.getTile(TilePos(blockTilePos.value + rel)).isAir);
        }
    }


    bool hasContent(vec3i relMin, vec3i relMax) {
        //TODO: Optimize this with kewl functions that counts/finds first set bit.
        foreach (pos; RangeFromTo(relMin, relMax)) {
            if(get(pos)) {
                return true;
            }
        }
        return false;
    }

}
static assert(SolidMap.data.sizeof == 2*65536); //64k yeah :)

version=UseCompressedFiles;
version(UseCompressedFiles) {
    alias CompressedBinaryFile FileInterface;
} else {
    alias BinaryFile FileInterface;
}

class Sector {

//    private TilePos pos;
    private SectorNum sectorNum;

    private Block_t[BlocksPerSector.x][BlocksPerSector.y][BlocksPerSector.z] blocks;
    static assert(blocks[0][0].length == BlocksPerSector.x);

    private SolidMap solidMap;


    //These are just cross-references.
    //At the moment they are not updated when units change sectors :P
    Unit[] units; //TODO: how to make this private without breaking stuff derp? :S
	Entity[] entities;

    this(SectorNum sectorNum_) {
        sectorNum = sectorNum_;
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

    const(Block_t)[] getBlocks() const {
        debug {
            auto b = &blocks[0][0][0];
            auto bb = b[0 .. BlocksPerSector.total];
            assert (&bb[0] is &blocks[0][0][0]);
            assert (&bb[$-1] is &blocks[$-1][$-1][$-1]);
        }

        return (&blocks[0][0][0])[0 .. BlocksPerSector.total];
    }
    
    void serialize() {
        string folder = text(g_worldPath ~ "/world/", sectorNum.value.x, ",", sectorNum.value.y, "/", sectorNum.value.z, "/");
        cgy.util.filesystem.mkdir(folder);
        
        //auto file = BinaryFile(folder ~ "blocks.bin", "wb");
        auto file = FileInterface(folder ~ "blocks.bin", "wb");
        
        auto writer = file.writer;
        
        Block_t[] allBlocks = (&blocks[0][0][0])[0 .. BlocksPerSector.total];
        //int validBlocks = allBlocks.reduce!"a + cast(int)b.valid";
        uint validBlocks = allBlocks.count!"a.valid".to!uint;
        writer.write(validBlocks);

        foreach( block ; allBlocks) {
            if (!block.valid) continue;
            block.serialize(writer);
        }
        file.close();
    }
    
    bool deserialize(WorldState world) {
        string folder = text(g_worldPath ~ "/world/", sectorNum.value.x, ",", sectorNum.value.y, "/", sectorNum.value.z, "/");
        if (!std.file.exists(folder)) {
            return false;
        }
        //auto file = BinaryFile(folder ~ "blocks.bin", "rb");
        auto file = FileInterface(folder ~ "blocks.bin", "rb");
        auto reader = file.reader;

        uint blockCount = reader.read!int;
        
        foreach(blockNum ; 0 .. blockCount) {
            Block_t block;
            block.deserialize(reader);
            auto num = block.blockNum.rel();
            BREAK_IF(blocks[num.z][num.y][num.x].tiles !is null);
            enforce(blocks[num.z][num.y][num.x].tiles is null, "Two blocks deserialized to same place in sector!");
            blocks[num.z][num.y][num.x] = block;
            solidMap.updateBlock(block);
            block.tiles = null;
        }
        file.close();
                
        return true;
    }
    
    private void generateBlock(BlockNum blockNum, WorldMap worldMap)
    in{
        assert(blockNum.getSectorNum() == sectorNum, "Trying to generate a block in the wrong sector!");
        auto pos = blockNum.rel();
        assert(blocks[pos.z][pos.y][pos.x] == INVALID_BLOCK, 
                text("Trying to generate a block which already contains stuff.",
                    blockNum));
    }
    body{
        BREAKPOINT;
        //THIS FUNCTION IS OUT OF COMMISION AND DEPRECATED!
        //WE NOW GENERATE WHOLE SECTORS AT A TIME INSTEAD!
        /*
        auto pos = blockNum.rel();
        auto block = Block.generateBlock(blockNum, worldMap);
        blocks[pos.z][pos.y][pos.x] = block;
        solidMap.updateBlock(block);
        */
    }

    void makeAirBlock(BlockNum blockNum) {
        auto pos = blockNum.rel();
        auto airBlock = AirBlock(blockNum);
        blocks[pos.z][pos.y][pos.x] = airBlock;
        solidMap.updateBlock(airBlock); //Can make a clearBlock ? 
    }

    Block getBlock(BlockNum blockNum)
    in{
        assert(blockNum.getSectorNum() == sectorNum);
    }
    body{
        auto pos = blockNum.rel();
        return &blocks[pos.z][pos.y][pos.x];
    }

    void unsafe_setBlock(Block_t block) {
        auto pos = block.blockNum.rel();        
        Block blockPtr = &blocks[pos.z][pos.y][pos.x];
        blockPtr.destroy;
        *blockPtr = block;

        solidMap.updateBlock(block);
    }

    bool hasContent(TilePos min, TilePos max) {
        auto relMin = min.sectorRel();
        auto relMax = max.sectorRel();
        return solidMap.hasContent(relMin, relMax);
    }

    bool isAirSector() {
        return !hasContent(TilePos(vec3i(0,0,0)),
                           TilePos(vec3i(SectorSize.x, SectorSize.y, SectorSize.z)-vec3i(1))
                           );
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
        units = units.remove(units.countUntil(u));
    }
    void removeEntity(Entity o) {
        entities = entities.remove(entities.countUntil(o));
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


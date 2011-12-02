
module world.world;

import std.algorithm;
import std.range;
import std.stdio;
import std.container;
import std.conv;
import std.exception;
import std.file;
import std.math;
import std.typecons;

import graphics.camera;
import graphics.debugging;

import json;
import light;
import tiletypemanager;
import entitytypemanager;
import unittypemanager;
import worldgen.worldgen;
public import unit;
public import entity;

import scheduler;
import statistics;

public import pos;
public import world.sizes;
public import world.sector;
public import world.block;
public import world.tile;
import util.util;
import util.intersect;
import util.rangefromto;
import util.tileiterator;
import util.filesystem;

import world.activity;
import world.ambient;
import world.floodfill;
import world.time;


// TODO: Refactor so these send world as first parameter,
// and remove the world member from listeners
interface WorldListener {
    void onAddUnit(SectorNum sectorNum, Unit* unit);
	void onAddEntity(SectorNum sectorNum, Entity entity);
    void onSectorLoad(SectorNum sectorNum);
    void onSectorUnload(SectorNum sectorNum);
    void onTileChange(TilePos tilePos);

    void onUpdateGeometry(TilePos tilePos);
    void onBuildGeometry(SectorNum sectorNum);
}


final class Heightmap {
    int[SectorSize.y][SectorSize.x] heightmap;

    void opIndexAssign(int val, size_t x, size_t y) {
        heightmap[x][y] = val;
    }
    ref int opIndex(size_t x, size_t y) {
        return heightmap[x][y];
    }
    this() {};
}

class World {

    static struct SectorXY {
        Heightmap heightmap;
        Sector[int] sectors;
    }

    final class HeightmapTaskState {
        SectorXYNum pos;
        Heightmap heightmap;
        int x, y, z;
        this(SectorXYNum p) {
            pos = p;
            heightmap = new Heightmap;
            x = 0;
            y = 0;
            z = int.max;
        }            
    }

    final class HeightmapTasks {
        HeightmapTaskState[] list;
    };
    HeightmapTasks heightmapTasks;

    SectorXY[SectorXYNum] sectorsXY;
    Sector[] sectorList;

    WorldGenParams worldGenParams;
    WorldGenerator worldGen;
    bool isServer;  //TODO: How, exactly, does the world function differently if it actually is a server? Find out!

    int unitCount;  //TODO: Is used?
	int entityCount;  //TODO: Is used?

    WorldListener[] listeners;

    TileTypeManager tileTypeManager;
	EntityTypeManager entityTypeManager;
	UnitTypeManager unitTypeManager;

    private alias RedBlackTree!(BlockNum, q{a.value < b.value}) WorkSet;
    WorkSet toFloodFill;
    SectorNum[] floodingSectors;

    this(WorldGenParams params, TileTypeManager tilesys, EntityTypeManager entitysys, UnitTypeManager unitsys) {
        isServer = true;
        tileTypeManager = tilesys;
        worldGen = new WorldGenerator;
		entityTypeManager = entitysys;
		unitTypeManager = unitsys;
        worldGenParams = params;
        worldGen.init(worldGenParams, tilesys);

        toFloodFill = new WorkSet;
        heightmapTasks = new HeightmapTasks;
    }

    void destroy() {
        worldGen.destroy();
    }

    void serialize() { 
        //TODO: Things commented should probably be serialized.
        //HeightmapTasks heightmapTasks;
        //WorldGenParams worldGenParams;
        //WorldGenerator worldGen;
        worldGen.serialize();
        //bool isServer;  //TODO: How, exactly, does the world function differently if it actually is a server? Find out!

        //WorldListener[] listeners;
        //TileTypeManager tileTypeManager;

        auto toFlood = encode(array(toFloodFill));
        auto floodSect = encode(floodingSectors);

        SectorNum[] actives;
        foreach(sector ; sectorList) {
            if (sector.activity > 0) {
                actives ~= sector.getSectorNum;
            }
        }
        auto activeSectors = Value(array(map!encode(actives)));
        auto jsonRoot = Value([
            "toFlood" : toFlood,
            "floodSect" : floodSect,
            "activeSectors" : activeSectors
        ]);

	    auto jsonString = json.prettifyJSON(jsonRoot);
        util.filesystem.mkdir("saves/current/world/");
        std.file.write("saves/current/world/world.json", jsonString);

        void serializeSectorXY(SectorXYNum xy, SectorXY sectorxy) {
            string folder = text("saves/current/world/", xy.value.X, ",", xy.value.Y, "/");
            util.filesystem.mkdir(folder);
            if (sectorxy.heightmap !is null) {
                std.file.write(folder ~ "heightmap.bin", sectorxy.heightmap.heightmap);
            }
            foreach( sector ; sectorxy.sectors) {
                sector.serialize();
            }
        }

        foreach( xy, sectorxy ; sectorsXY) {
            serializeSectorXY(xy, sectorxy);
        }
    }

    void deserialize() {
        worldGen.deserialize();

        auto content = readText("saves/current/world/world.json");
        auto jsonRoot = json.parse(content);
        uint activeUnitId;
        uint unitCount;
        toFloodFill = new typeof(toFloodFill);
        json.read(toFloodFill, jsonRoot["toFlood"]);
        json.read(floodingSectors, jsonRoot["floodSect"]);
        SectorNum[] actives;
        json.read(actives, jsonRoot["activeSectors"]);
        foreach(sectorNum ; actives) {
            loadSector(sectorNum);
        }

    }


    //Ensure that it only happens when no other code is running.
    Sector loadSector(SectorNum num)
    in{
        BREAK_IF(getSector(num) !is null);
    }
    body{
        void loadSectorXY(SectorXYNum xy) {
            SectorXY* xyPtr = getSectorXY(xy, false);
            string folder = text("saves/current/world/", xy.value.X, ",", xy.value.Y, "/");
            if (exists(folder ~ "heightmap.bin")) {
                Heightmap heightmap = new Heightmap;            
                heightmap.heightmap = cast(int[128][])std.file.read(folder ~ "heightmap.bin");
                xyPtr.heightmap = heightmap;
            } else {
                heightmapTasks.list ~= new HeightmapTaskState(xy);
                g_Statistics.HeightmapsNew(SectorSize.x * SectorSize.y);                
            }
        }

        auto xyNum = SectorXYNum(vec2i(num.value.X, num.value.Y));
        SectorXY* xyPtr = xyNum in sectorsXY;
        if (xyPtr is null) {
            loadSectorXY(xyNum);
        }

        auto sector = allocateSector(num);
        if (sector.deserialize(entityTypeManager, this)) {
            notifySectorLoad(num);
            notifyBuildGeometry(num);
        }
        return sector;
    }


    //This function generates a block of world.
    //If the block is decidedly above ground level, we use a shortcut and set it as a sparse air block immediately.
    //Otherwise we let the world-generator produce a block for us.
    //TODO: Measure the time it takes to check for above-ground-level for comparisons.
    void generateBlock(BlockNum blockNum) {
        SectorXY* xy;
        auto sectorNum = blockNum.getSectorNum();
        auto sector = getSector(sectorNum, &xy);
        enforce(sector !is null, "Cant generate block in sector that isnt allocated yet");
        auto heightmap = xy.heightmap;
        bool above = true;
        if(heightmap !is null) {
            auto tp = blockNum.toTilePos();
            auto sectTp = sectorNum.toTilePos();
            auto sectToBlock = tp.value - sectTp.value;
            foreach(rel ; RangeFromTo (0, BlockSize.x-1,
                                       0, BlockSize.y-1,
                                       0, 0)) {
                                           auto heightmapIndex = rel + sectToBlock;
                                           if (tp.value.Z <= heightmap[heightmapIndex.X, heightmapIndex.Y]){
                                               above = false;
                                               break;
                                           }
                                       }
            if (above) {
                sector.makeAirBlock(blockNum);
                return;
            }
        }
        sector.generateBlock(blockNum, worldGen);
    }

    void generateHeightmapTaskFunc(HeightmapTaskState state) {
        enum iterationLimit = 10_000;
        auto xy = state.pos;
        auto p = xy.getTileXYPos();
        int iterations = 0;
        int done = 0;
        int yStart = state.y;
        foreach (x ; state.x .. SectorSize.x) {
            foreach (y ; yStart .. SectorSize.y) {
                yStart = 0;
                auto tmp = p.value + vec2i(x, y);
                int z;
                auto posXY = TileXYPos(tmp);
                if (state.z == int.max) {
                    z = worldGen.maxZ(posXY);
                }

                if(worldGen.isInsideWorld(TilePos(vec3i(posXY.value.X, posXY.value.Y, z)))) {
                    while (worldGen.getTile(TilePos(vec3i(
                                                          posXY.value.X, posXY.value.Y, z))).type
                           is TileTypeAir) {
                               z -= 1;
                               iterations++;
                               if (iterations >= iterationLimit) {
                                   state.x = x;
                                   state.y = y;
                                   state.z = z;
                                   g_Statistics.HeightmapsProgress(done);
                                   return;
                               }
                           }
                }
                state.z = int.max;
                state.heightmap[x, y] = z;
                done++;
            }
        }
        synchronized(heightmapTasks) {
            bool pred(HeightmapTaskState a) {
                return a == state;
            }
            heightmapTasks.list = remove!pred(heightmapTasks.list);
            if (heightmapTasks.list.empty) {
                g_Statistics.HeightmapsNew(0);
            }
        }
        getSectorXY(xy).heightmap = state.heightmap;
        g_Statistics.HeightmapsProgress(done);        
    }

    //Causes blocking, yeah!
    void generateAllHeightmaps() {
        synchronized(heightmapTasks) {
            while (!heightmapTasks.list.empty) {
                generateHeightmapTaskFunc(heightmapTasks.list[0]);
            }
        }
    }

    //TODO: Somehow ensure that we're only called from allocateSector
    //Why would we want this, hmmm?
    //TODO: This function suffers from a horrible bugish behaviour
    //If there is a sectorXY, then it is returned and all is well, EXCEPT for the fact that
    // if the sectorXY does not contain anything in it's .sectors-AA, then adding anthing to
    // that copy of SectorXY will not affect what is stored in the sectorXY-list.
    SectorXY* getSectorXY(SectorXYNum xy, bool generateHeightmap = true)
    body{
        SectorXY* xyPtr = xy in sectorsXY; //One fast lookup. Ptr is only used these three lines.
        if (xyPtr !is null) {
            return xyPtr;
        }
        //We didnt have it. Create it, and a heightmap along with it!
        SectorXY ret;
        if (generateHeightmap) {
            synchronized(heightmapTasks) {
                heightmapTasks.list ~= new HeightmapTaskState(xy);
                g_Statistics.HeightmapsNew(SectorSize.x * SectorSize.y);
            }
        }

        sectorsXY[xy] = ret; //Spara det vi skapar, yeah!
        return &sectorsXY[xy]; //Return address of AAAARRRRGGGHHHH
    }

    Sector allocateSector(SectorNum sectorNum, SectorXY** xy = null) {
        auto xyNum = SectorXYNum(vec2i(sectorNum.value.X, sectorNum.value.Y));
        auto z = sectorNum.value.Z;

        //If has not has sectorXY, make one
        SectorXY* xyPtr = getSectorXY(xyNum);

        auto sector = new Sector(sectorNum);
        assert(sector !is null, "derp!");

        assert (z !in xyPtr.sectors);
        xyPtr.sectors[z] = sector;
        sectorList ~= sector;

        if (xy !is null) {
            *xy = xyPtr;
        }
        return sector;
    }

    //Returns a sector. Does not allocate sectors.
    Sector getSector(SectorNum sectorNum, SectorXY** xy=null) {
        auto xyNum = SectorXYNum(vec2i(sectorNum.value.X, sectorNum.value.Y));
        auto z = sectorNum.value.Z;

        SectorXY* xyPtr = xyNum in sectorsXY;
        Sector* ptr;
        if( xyPtr !is null) {
            ptr = z in xyPtr.sectors;
            if (ptr !is null) {
                if (xy !is null) {
                    *xy = xyPtr; //This is 'safe' ; If the xyPtr is valid AND ptr is valid, then
                    //copying SectorXY will work since it's .sectors is non-empty :)
                }
                return *ptr;
            }
        }
        return null;
    }

    SolidMap* getSolidMap(TilePos tilePos) {
        auto sectorNum = tilePos.getSectorNum();
        auto sector = getSector(sectorNum);
        if(sector is null) {
            return null;
        }
        return sector.getSolidMap();
    }


    Block* getBlockLastBlock = null;
    BlockNum getBlockLastBlockNum = BlockNum(vec3i(int.min));
    private Block* getBlock(BlockNum blockNum, bool generate=false) {
        /*
        if (blockNum == getBlockLastBlockNum) {
            return getBlockLastBlock;
        }
        */
        auto sector = this.getSector(blockNum.getSectorNum());
        if (sector is null) return &INVALID_BLOCK;

        auto block = sector.getBlock(blockNum);
        if (!block.valid) {
            if (!generate) return &INVALID_BLOCK;

            //TODO: Pass sector as parameter, to make generateBlock not have to look it up itself?
            generateBlock(blockNum); //Somewhere in this, we make a new sector. Or an old one. Dont know yet.
            block = sector.getBlock(blockNum);
        }
        BREAKPOINT(!block.valid);
        assert (block.valid);
        //getBlockLastBlockNum = blockNum;
        //getBlockLastBlock = block;
        return block;
    }

    private void setBlock(BlockNum blockNum, Block newBlock) {
        enforce(0, "Deprecated. see Sector.setBlock.");
        auto sector = getSector(blockNum.getSectorNum());
        sector.setBlock(blockNum, newBlock);
    }

    // I'd rather not have this in world //plol
    //TODO: Add code to cull sectors
    //TODO: Make better interface than appending to a dynamic list?
    Unit*[] getVisibleUnits(Camera camera){
        // this should be array(filter!(camera.inFrustum)(getUnits()));
        // but that doesn't seem to work :(
        Unit*[] units;
        foreach(unit; getUnits()){
            if(camera.inFrustum(unit)){
                units ~= unit;
            }
        }
        return units;
    }
	Entity[] getVisibleEntities(Camera camera){
        Entity[] entities;
        foreach(entity; getEntities()){
            if(camera.inFrustum(entity)){
                entities ~= entity;
            }
        }
        return entities;
    }

    private Sector[] getSectors() {
        return sectorList;
    }

    static struct UnitRange {
        Sector[] sectors;
        typeof(Sector.init.units[]) currentUnitRange;

        Unit* front() @property {
            return currentUnitRange.front;
        }
        void popFront() {
            currentUnitRange.popFront();
            prop();
        }
        void prop() {
            if(sectors.empty) return;
            while (currentUnitRange.empty) {
                sectors.popFront();
                if (sectors.empty) break;
                currentUnitRange = sectors.front.units[];
            }
        }

        bool empty() @property {
            return sectors.empty && currentUnitRange.empty;
        }
    }

    // Returns a range with all the units in the world
    UnitRange getUnits() {
        UnitRange ret;
        ret.sectors = getSectors();
        if (!ret.sectors.empty) {
            ret.currentUnitRange = ret.sectors.front.units[];
        }
        ret.prop();
        return ret;
    }

    Unit* getUnitFromId(uint id) {
        foreach(unit ; getUnits()) {
            if (unit.unitId == id) {
                return unit;
            }
        }
        return null;
    }

	/////////////// Samma lika fast med entities
	static struct EntityRange {
        Sector[] sectors;
        typeof(Sector.init.entities[]) currentEntityRange;

        Entity front() @property {
            return currentEntityRange.front;
        }
        void popFront() {
            currentEntityRange.popFront();
            prop();
        }
        void prop() {
            if(sectors.empty) return;
            while (currentEntityRange.empty) {
                sectors.popFront();
                if (sectors.empty) break;
                currentEntityRange = sectors.front.entities[];
            }
        }

        bool empty() @property {
            return sectors.empty && currentEntityRange.empty;
        }
    }

    // Returns a range with all the entities in the world
    EntityRange getEntities() {
        EntityRange ret;
        ret.sectors = getSectors();
        if (!ret.sectors.empty) {
            ret.currentEntityRange = ret.sectors.front.entities[];
        }
        ret.prop();
        return ret;
    }

    Entity getEntityFromId(uint id) {
        foreach(entity ; getEntities()) {
            if (entity.entityId == id) {
                return entity;
            }
        }
        return null;
    }
	///////////////// inge mer entity kod!

    void update(Scheduler scheduler){
        floodFillSome();

        synchronized(heightmapTasks) { //Not needed, since only thread working now. Anyway.. :)
            foreach(state ; heightmapTasks.list) {
                //Trixy trick below; if we dont do this, the value num will be shared by all pushed tasks.
                (HeightmapTaskState state){
                    scheduler.push(asyncTask(
                                             (const(World) world){
                                                 generateHeightmapTaskFunc(state);
                                             }));
                }(state);
            }        
        }

        //MOVE UNITS
        //TODO: Make list of only-moving units, so as to not process every unit?
        //Maybe?
        // :)
        //TODO: Consider AI-notification of arrival ?
        foreach(unit ; getUnits()) {
            if(unit.ticksToArrive == 0) continue;
            auto vel = unit.destination.value - unit.pos.value;
            vel *= 1.0/unit.ticksToArrive;
            unit.velocity = vel;
            unit.ticksToArrive -= 1;
            if(unit.ticksToArrive == 0){
                unit.velocity.set(0, 0, 0);
            }
            moveUnit(unit, UnitPos(unit.pos.value + vel));
        }

        updateTime();
    }

    // ONLY CALLED FROM CHANGELIST (And some CustomChange-implementations )
    void unsafeMoveUnit(Unit* unit, vec3d destination, uint ticksToArrive){
        unit.destination = UnitPos(destination);
        unit.ticksToArrive = ticksToArrive;
        //Maybe add to list of moving units? Maybe all units are moving?
        //Consider this later. Related to comment in world.update
    }


    private void moveUnit(Unit* unit, UnitPos newPos) {
        moveActivity(unit.pos, newPos);

        unit.pos = newPos;
    }

    //TODO: Implement removeUnit?
    // These should be named unsafeAddUnit, right?
    void addUnit(Unit* unit) {
        unitCount += 1;
        auto sectorNum = unit.pos.getSectorNum();

        increaseActivity(unit.pos);
        getSector(sectorNum).addUnit(unit);

        notifyAddUnit(sectorNum, unit);
    }
	void addEntity(Entity entity) {
        entityCount += 1;
        auto sectorNum = entity.pos.getSectorNum();

        auto sector = getSector(sectorNum);

        enforce(sector !is null, "Cant add entities to sectors that dont exist");

        sector.addEntity(entity);
        notifyAddEntity(sectorNum, entity);

        addLightFromEntity(entity);
    }
    void removeEntity(Entity entity) {
        auto sector = getSector(entity.pos.getSectorNum());
        sector.removeEntity(entity);
        if (entity.type.lightStrength > 0) {
            unsafeRemoveLight(entity.light);
        }

        // TODO: do we have to release the memory perhaps?
    }
    void addLightFromEntity(Entity entity) {
        if (entity.type.lightStrength > 0) {
            LightSource light = new LightSource;
            light.position = entity.pos;
            light.tint.set(entity.type.lightTintColor);
            light.strength = entity.type.lightStrength;
            entity.light = light;
            unsafeAddLight(light);
        }
    }

    //We only create blocks when we floodfill; this the default for this parameter is henceforth "false"

    Tile getTile(TilePos tilePos, bool createBlock=false) {
        auto block = getBlock(tilePos.getBlockNum(), createBlock);
        if(!block.valid){
            return INVALID_TILE;
        }
        return block.getTile(tilePos);
    }

    bool isSolid(TilePos tilePos) {
        auto sectorNum = tilePos.getSectorNum();
        auto sector = getSector(sectorNum);
        if(sector is null) return false;
        return sector.isSolid(tilePos);
    }

    //Returns number of iterations nexxxessarrry to intersect a non-air tile.
    //Returns 0 on instant-found or none found.
    //Returns -1 on invalid tile found
    int intersectTile(vec3d start, vec3d dir, int tileIter, ref Tile outTile, ref TilePos outPos, ref vec3i Normal, double* intersectionTime = null) {
        TilePos oldTilePos;
        int cnt;
        foreach(tilePos ; TileIterator(start, dir, tileIter, intersectionTime)) {
            cnt++;
            auto tile = getTile(tilePos, false);
            if (tile.type == TileTypeInvalid) {
                return -1;
            }
            scope(exit) oldTilePos = tilePos;
            if (tile.type != TileTypeAir) {
                outPos = tilePos;
                Normal = oldTilePos.value - tilePos.value;
                outTile = tile;
                return cnt;
            }
        }
        return 0;
    }

    bool rayCollides(vec3d start, vec3d end) {
        auto dir = end - start;
        auto len = dir.getLength();
        dir.normalize();
        int tileIter = cast(int)(ceil(abs(dir.X)) + ceil(abs(dir.Y)) + ceil(abs(dir.Z)));
        double intersectionTime;
        foreach(tilePos ; TileIterator(start, dir, tileIter, &intersectionTime)) {
            if(intersectionTime > len) {
                return false;
            }
            auto tile = getTile(tilePos, false);
            if (tile.type == TileTypeInvalid) {
                return true;
            }
            if (!tile.isAir) {
                return true;
            }
        }
        return false;
    }

    private void setTileLightVal(TilePos tilePos, const byte newVal, bool isSunLight) {
        //TODO: Make sure penis penis penis, penises.
        //Durr, i mean, make sure to floodfill as well! :)
        auto blockNum = tilePos.getBlockNum();
        auto block = getBlock(blockNum, false); //Dont arbitrarily create blocks. Why would we set lightvals in blocks that dont exist?
        if(!block.valid) {
            return;
        }
        block.setTileLight(tilePos, newVal, isSunLight);

        //notifyTileChange(tilePos);
    }

    void unsafeSetTile(TilePos pos, Tile tile) {
        //TODO: Think of any reason for or against calling setTile directly here.
        //Like, maybe store it up and do setting in world.update()?
        setTile(pos, tile);
    }

    //Now only called from unsafeSetTile
    private void setTile(TilePos tilePos, const Tile newTile) {
        //TODO: Make sure penis penis penis, penises.
        //Durr, i mean, make sure to floodfill as well! :)
        auto sectorNum = tilePos.getSectorNum();
        SectorXY* sectorXY;
        auto sector = getSector(sectorNum, &sectorXY);

        auto blockNum = tilePos.getBlockNum();
        //auto block = getBlock(blockNum, true);
        auto block = sector.getBlock(blockNum); //No blocks are generated here :)
        BREAKPOINT(!block.valid);
        auto oldTile = block.getTile(tilePos);
        block.setTile(tilePos, newTile);
        bool newSolid = !newTile.isAir();
        bool oldSolid = sector.setSolid(tilePos, newSolid);

        //Only works to not set blocknum again, if we already
        // have a block of memory that block.tiles points to;
        // since then we'd be writing into the correct memory.
        // a block is really read-only, but block.tiles if
        // present is read-write.
        //Start floodfill, and updating of discovered areas
        if (newTile.type is TileTypeAir) {
            block.seen = false; //To enable floodfilling of area again.
            addFloodFillPos(tilePos);
        }


        //Update heightmap
//        auto sectorXY = getSectorXY(SectorXYNum(vec2i(sectorNum.value.X, sectorNum.value.Y)));
        auto heightmap = sectorXY.heightmap;
        auto sectRel = tilePos.sectorRel();
        auto heightmapZ = heightmap[sectRel.X, sectRel.Y];
        if (heightmapZ == tilePos.value.Z) {
            if (newTile.type is TileTypeAir) {
                auto pos = tilePos;
                //Iterate down until find ground, set Z
                while (getTile(pos, false).type is TileTypeAir) { //Create geometry if we need to
                    pos.value.Z -= 1;
                }
                heightmap[sectRel.X, sectRel.Y] = pos.value.Z;
            }
        } else if (heightmapZ < tilePos.value.Z) {
            if (newTile.type !is TileTypeAir) {
                heightmap[sectRel.X, sectRel.Y] = tilePos.value.Z;
            }
        }

        if(oldSolid && !newSolid) { //Added air
            removeTile(tilePos);
        } else if( !oldSolid && newSolid ){ //Removed air
            addTile(tilePos, oldTile);
        }

        notifyTileChange(tilePos);
    }

    TilePos getTopTilePos(TileXYPos xy) {
        auto rel = xy.sectorRel();
        auto x = rel.X;
        auto y = rel.Y;

        auto t = xy.getSectorXYNum();
        auto sectorXY = getSectorXY(t);

        auto heightmap = sectorXY.heightmap;
        if (heightmap is null ) {
            int z = worldGen.maxZ(xy);
            auto tp = TilePos(vec3i(xy.value.X, xy.value.Y, z));
            if(!worldGen.isInsideWorld(tp)) {
                return tp;
            }
            while (worldGen.getTile(TilePos(vec3i(
                                                  xy.value.X, xy.value.Y, z))).type
                   is TileTypeAir) {
                       z -= 1;
                   }
            return TilePos(vec3i(xy.value.X, xy.value.Y, z));
        }
        assert(heightmap !is null, "heightmap == null! :(");
        auto pos = vec3i(xy.value.X, xy.value.Y, heightmap[x, y]);
        return TilePos(pos);
    }

    bool hasContent(TilePos min, TilePos max) {
        auto sectorMin = min.getSectorNum();
        auto sectorMax = max.getSectorNum();
        foreach(rel ; RangeFromTo(sectorMin.value, sectorMax.value)) {
            auto sectorNum = SectorNum(rel);
            auto sectorStartTilePos = sectorNum.toTilePos();
            auto sectorStopTilePos = TilePos(sectorStartTilePos.value + vec3i(SectorSize.x-1, SectorSize.y-1, SectorSize.z-1));
            int minX = std.algorithm.max(sectorStartTilePos.value.X, min.value.X);
            int minY = std.algorithm.max(sectorStartTilePos.value.Y, min.value.Y);
            int minZ = std.algorithm.max(sectorStartTilePos.value.Z, min.value.Z);

            int maxX = std.algorithm.min(sectorStopTilePos.value.X, max.value.X);
            int maxY = std.algorithm.min(sectorStopTilePos.value.Y, max.value.Y);
            int maxZ = std.algorithm.min(sectorStopTilePos.value.Z, max.value.Z);
            auto sector = getSector(sectorNum);
            if (sector.hasContent(TilePos(vec3i(minX, minY, minZ)), TilePos(vec3i(maxX, maxY, maxZ)))) {
                return true;
            }
        }
        return false;
    }

    void addListener(WorldListener listener) {
        listeners ~= listener;
    }
    void removeListener(WorldListener listener) {
        remove(listeners, countUntil!q{a is b}(listeners, listener));
        listeners.length -= 1;
    }

    void notifyAddUnit(SectorNum sectorNum, Unit* unit) {
        foreach (listener; listeners) {
            listener.onAddUnit(sectorNum, unit);
        }
    }
	void notifyAddEntity(SectorNum sectorNum, Entity entity) {
        foreach (listener; listeners) {
            listener.onAddEntity(sectorNum, entity);
        }
    }
    void notifySectorLoad(SectorNum sectorNum) {
        foreach (listener; listeners) {
            listener.onSectorLoad(sectorNum);
        }
    }
    void notifySectorUnload(SectorNum sectorNum) {
        foreach (listener; listeners) {
            listener.onSectorUnload(sectorNum);
        }
    }
    void notifyTileChange(TilePos tilePos) {
        foreach (listener; listeners) {
            listener.onTileChange(tilePos);
        }
    }
    void notifyBuildGeometry(SectorNum sectorNum) {
        foreach (listener; listeners) {
            listener.onBuildGeometry(sectorNum);
        }
    }
    void notifyUpdateGeometry(TilePos tilePos) {
        foreach (listener; listeners) {
            listener.onUpdateGeometry(tilePos);
        }
    }


    mixin WorldTimeClockCode;
    mixin LightStorageMethods;
    mixin ActivityHandlerMethods;
    mixin FloodFill;

}

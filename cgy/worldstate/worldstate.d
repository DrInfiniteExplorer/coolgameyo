
module worldstate.worldstate;

import std.algorithm;
import std.container;
import std.conv;
import std.exception;
//import std.file;
import std.math;
import std.parallelism;
import std.range;
import std.stdio;
import std.typecons;


import changes.worldproxy;
import clan;
import clans;

public import entities.entity;
import entitytypemanager;

import gaia;
import graphics.camera;
import graphics.debugging;

import json;
import light;

import globals : g_isServer;

//import worldgen.worldgen;

public import util.pos;

import scene.scenemanager;
import scheduler;
import statistics;

import tiletypemanager;

public import unit;
import unittypemanager;

import util.util;
import util.intersect;
import util.memory;
import util.rangefromto;
import util.tileiterator;
import util.filesystem;

import          worldstate.activity;
import          worldstate.ambient;
public import   worldstate.block;
import          worldstate.floodfill;
import          worldstate.heightmap;
public import   worldstate.sector;
public import   worldstate.sizes;
public import   worldstate.tile;
import          worldstate.time;

import worldgen.maps;


// TODO: Refactor so these send world as first parameter,
// and remove the world member from listeners
interface WorldStateListener {
    void onAddUnit(SectorNum sectorNum, Unit unit);
    void onAddEntity(SectorNum sectorNum, Entity entity);
    void onSectorLoad(SectorNum sectorNum);
    void onSectorUnload(SectorNum sectorNum);
    void onTileChange(TilePos tilePos);

    void onUpdateGeometry(TilePos tilePos);
    void onBuildGeometry(SectorNum sectorNum);
}



class WorldState {

    static struct SectorXY {
        SectorHeightmap heightmap;
        Sector[int] sectors;
    }

    SectorXY[SectorXYNum] sectorsXY;
    Sector[SectorNum] sectorList;

    //WorldGenParams worldGenParams;


    WorldStateListener[] listeners;

    TileTypeManager tileTypeManager;
    EntityTypeManager entityTypeManager;
    UnitTypeManager unitTypeManager;
    SceneManager sceneManager;

    WorldMap worldMap;

    mixin WorldTimeClockCode;
    mixin LightStorageMethods;
    mixin ActivityHandlerMethods;
    mixin FloodFill;
    mixin Heightmap;

    bool updatePhase = true;
    void enforceUpdate() {
        BREAK_IF(!updatePhase);
        enforce(updatePhase, "Tries to do update-code when not in update");
    }

    WorldProxy _worldProxy;
    WorldProxy worldProxy() @property {
        enforceUpdate();
        return _worldProxy;
    }

    this(WorldMap _worldMap, TileTypeManager tilesys, EntityTypeManager entitysys, UnitTypeManager unitsys, SceneManager _sceneManager) {
        tileTypeManager = tilesys;
        worldMap = _worldMap;
        entityTypeManager = entitysys;
        unitTypeManager = unitsys;
        //worldGenParams = params;
        sceneManager = _sceneManager;

        _worldProxy = new WorldProxy(this);
        Clans().init(this);

        initFloodfill();
        initHeightmap();

        createGaia();

    }

    void destroy() {
    }

    void createGaia() {
        Gaia().init(this);

    }

    void serialize() { 
        //TODO: Totally redo serialization.

        //TODO: Things commented should probably be serialized.
        //HeightmapTasks heightmapTasks;
        //WorldGenParams worldGenParams;
        //WorldGenerator worldGen;

        //worldGen.serialize();
        //bool isServer;  //TODO: How, exactly, does the world function differently if it actually is a server? Find out!

        //WorldStateListener[] listeners;
        //TileTypeManager tileTypeManager;


        auto activeSectors = encode(activeSectors);
        auto jsonRoot = Value([
                "activeSectors" : activeSectors,
                "g_UnitCount" : encode(g_UnitCount),
                "g_entityCount" : encode(g_entityCount),
                "g_ClanCount" : encode(g_ClanCount),
                ]);

        serializeFloodfill(jsonRoot);

        auto jsonString = json.prettifyJSON(jsonRoot);
        util.filesystem.mkdir(g_worldPath ~ "/world/");
        std.file.write(g_worldPath ~ "/world/world.json", jsonString);

        Clans().serializeClans();


        foreach(xy, sectorXY ; sectorsXY) {
            serializeHeightmap(xy, &sectorXY);
            foreach(sector ; sectorXY.sectors) {
                sector.serialize();
            }
        }

    }

    void serializeHeightmap(SectorXYNum xy, SectorXY* sectorXY) {
        string folder = text(g_worldPath ~ "/world/", xy.value.x, ",", xy.value.y, "/");
        util.filesystem.mkdir(folder);
        if (sectorXY.heightmap !is null) {
            std.file.write(folder ~ "heightmap.bin", sectorXY.heightmap.heightmap);
        }
    }

    void deserialize() {
        //TODO: Totally redo serialization.
        //worldGen.deserialize();

        if(!exists(g_worldPath ~ "/world/world.json")) {
            return; // Nothing to deserialize
        }
        auto content = readText(g_worldPath ~ "/world/world.json");
        auto jsonRoot = json.parse(content);
        uint activeUnitId;

        deserializeFloodfill(jsonRoot);
        jsonRoot.readJSONObject(
                                "activeSectors",    &activeSectors,
                                "g_UnitCount",      &g_UnitCount,
                                "g_entityCount",    &g_entityCount,
                                "g_ClanCount",      &g_ClanCount);

        Clans().deserializeClans();

        foreach(sectorNum, clanCount ; activeSectors) {
            if(getSector(sectorNum) !is null) continue; //Means the sector is already loaded.
            if(!clanCount) {
                msg("Error, nonexistent clancount for sector, ignoring. ", sectorNum);
            } else {
                loadSector(sectorNum);
            }
        }

    }

    bool removeSector(SectorNum sectorNum) {
        auto xy = SectorXYNum(sectorNum);
        SectorXY* sectorXY;
        auto sector = getSector(sectorNum, &sectorXY);
        sector.destroy();

        enforce(sectorNum.value.z in sectorXY.sectors, "Terp yerp lerp");
        sectorXY.sectors.remove(sectorNum.value.z);
        sectorList.remove(sectorNum);
        return sectorXY.sectors.length == 0;
    }


    //Ensure that it only happens when no other code is running.
    // Why? This might be a problem soon.
    Sector loadSector(SectorNum num)
    in{
        BREAK_IF(getSector(num) !is null);
    }
    body{
        void loadSectorXY(SectorXYNum xy) {
            SectorXY* xyPtr = getSectorXY(xy, false);
            string folder = text(g_worldPath ~ "/world/", xy.value.x, ",", xy.value.y, "/");
            if (util.filesystem.exists(folder ~ "heightmap.bin")) {
                SectorHeightmap heightmap = new SectorHeightmap;            
                heightmap.heightmap[] = (cast(int[128][])std.file.read(folder ~ "heightmap.bin"))[];
                xyPtr.heightmap = heightmap;
            } else {
                addHeightmapTask(xy);
            }
        }

        auto xyNum = SectorXYNum(vec2i(num.value.x, num.value.y));
        SectorXY* xyPtr = xyNum in sectorsXY;
        if (xyPtr is null) {
            loadSectorXY(xyNum);
        }

        auto sector = allocateSector(num);
        if (sector.deserialize(entityTypeManager, this)) {
            notifySectorLoad(num);
            notifyBuildGeometry(num);
        } else {
            addFloodFillSector(num);
        }
        return sector;
    }

    bool hasSectorXY(SectorXYNum xy) {
        return (xy in sectorsXY) !is null;
    }

    //TODO: Somehow ensure that we're only called from allocateSector
    //Why would we want this, hmmm?
    //TODO: This function suffers from a horrible bugish behaviour
    //If there is a sectorXY, then it is returned and all is well, EXCEPT for the fact that
    // if the sectorXY does not contain anything in it's .sectors-AA, then adding anthing to
    // that copy of SectorXY will not affect what is stored in the sectorXY-list.
    SectorXY* getSectorXY(SectorXYNum xy, bool generateHeightmap = true) {
        SectorXY* xyPtr = xy in sectorsXY; //One fast lookup. Ptr is only used these three lines.
        if (xyPtr !is null) {
            return xyPtr;
        }
        //We didnt have it. Create it, and a heightmap along with it!
        SectorXY ret;
        if (generateHeightmap) {
            addHeightmapTask(xy);
        }

        sectorsXY[xy] = ret; //Spara det vi skapar, yeah!
        return &sectorsXY[xy]; //Return address of AAAARRRRGGGHHHH
    }

    Sector allocateSector(SectorNum sectorNum, SectorXY** xy = null) {
        auto xyNum = SectorXYNum(vec2i(sectorNum.value.x, sectorNum.value.y));
        auto z = sectorNum.value.z;

        //If has not has sectorXY, make one
        SectorXY* xyPtr = getSectorXY(xyNum);

        auto sector = new Sector(sectorNum);
        assert(sector !is null, "derp!");

        assert (z !in xyPtr.sectors);
        xyPtr.sectors[z] = sector;
        sectorList[sectorNum] = sector;

        if (xy !is null) {
            *xy = xyPtr;
        }
        return sector;
    }

    //Returns a sector. Does not allocate sectors.
    Sector getSector(SectorNum sectorNum, SectorXY** xy=null) {
        auto xyNum = SectorXYNum(vec2i(sectorNum.value.x, sectorNum.value.y));
        auto z = sectorNum.value.z;

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

    bool isAirSector(SectorNum sectorNum) {
        auto sector = getSector(sectorNum);
        if(sector is null) return false;
        return sector.isAirSector();
    }

    SolidMap* getSolidMap(TilePos tilePos) {
        auto sectorNum = tilePos.getSectorNum();
        auto sector = getSector(sectorNum);
        if(sector is null) {
            return null;
        }
        return sector.getSolidMap();
    }


    Block getBlockLastBlock = null;
    BlockNum getBlockLastBlockNum = BlockNum(vec3i(int.min));
    private Block getBlock(BlockNum blockNum) {
        /*
           if (blockNum == getBlockLastBlockNum) {
           return getBlockLastBlock;
           }
         */
        auto sector = this.getSector(blockNum.getSectorNum());
        if (sector is null) return &INVALID_BLOCK;

        auto block = sector.getBlock(blockNum);
        if (!block.valid) {
            return &INVALID_BLOCK;
        }
        BREAK_IF(!block.valid);
        assert (block.valid);
        //getBlockLastBlockNum = blockNum;
        //getBlockLastBlock = block;
        return block;
    }

    // I'd rather not have this in world //plol
    //TODO: Add code to cull sectors
    //TODO: Make better interface than appending to a dynamic list?
    Unit[] getVisibleUnits(Camera camera){
        // this should be array(filter!(camera.inFrustum)(getUnits()));
        // but that doesn't seem to work :(
        Unit[] units;
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

    private Sector[SectorNum] getSectors() {
        return sectorList;
    }

    static struct UnitRange {
        Sector[] sectors;
        typeof(Sector.init.units[]) currentUnitRange;

        Unit front() @property {
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
        ret.sectors = getSectors().values;
        if (!ret.sectors.empty) {
            ret.currentUnitRange = ret.sectors.front.units[];
        }
        ret.prop();
        return ret;
    }

    Unit getUnitFromId(uint id) {
        foreach(unit ; getUnits()) {
            if (unit.id == id) {
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
        ret.sectors = getSectors().values;
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
    ///////////////// inge mer entity kod! <- lol

    void update(Scheduler scheduler){
        updatePhase = true;
        allTilesUpdated(); //Updates lighting and triggers regeneration of geometry
        scope(exit) updatePhase = false;
        //floodFillSome();

        pushFloodFillTasks(scheduler);
        pushHeightmapTasks(scheduler);
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

        handleSectorTimeout();
    }

    // ONLY CALLED FROM CHANGELIST (And some CustomChange-implementations )
    void unsafeMoveUnit(Unit unit, UnitPos destination, uint ticksToArrive){
        unit.destination = destination;
        unit.ticksToArrive = ticksToArrive;
        //Maybe add to list of moving units? Maybe all units are moving?
        //Consider this later. Related to comment in world.update
        if(!g_isServer) {
            auto proxy = sceneManager.getProxy(unit);
            proxy.setDestination(destination.value, ticksToArrive);
        }
    }


    private void moveUnit(Unit unit, UnitPos newPos) {
        auto clan = unit.clan;
        auto oldPos = unit.pos;
        if(clan.unitMoveActivity(unit.pos, newPos)) {

            //Update the boolean map the world has of activities.
            updateActivity(oldPos, newPos);
        }

        unit.pos = newPos;
    }

    //TODO: Implement removeUnit?
    // These should be named unsafeAddUnit, right?
    void addUnit(Unit unit) {
        msg("Adding unit at ", unit.pos);
        enforce(unit.clan !is null);

        if(!g_isServer) {
            //pragma(msg, "We should create link between scenegraph and unit here. Programmatic creation of units reach here, and loading & change-induced creation does as well");
            sceneManager.getProxy(unit);
        }

        //Update boolean activity map
        updateActivity(unit.pos, unit.pos);

        //Eventually make the clan the main unit storage place.
        //And just use units in sectors for cross-referencing.
        auto sectorNum = unit.pos.getSectorNum();
        getSector(sectorNum).addUnit(unit);


        notifyAddUnit(sectorNum, unit);
    }
    void addEntity(Entity entity) {
        //TODO: Make code, and make it work. Use unit as reference.
        if(!g_isServer) {
            if(entity.type.hasModellike()) {
                sceneManager.getProxy(entity);
            }
        }

        auto sectorNum = entity.pos.getSectorNum();
        auto sector = getSector(sectorNum);
        if(sector is null) return;

        enforce(sector !is null,
                "Cant add entities to sectors that dont exist");

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
            light.tint = entity.type.lightTintColor;
            light.strength = entity.type.lightStrength;
            entity.light = light;
            unsafeAddLight(light);
        }
    }

    //We only create blocks when we floodfill; this the default for this parameter is henceforth "false"

    Tile getTile(TilePos tilePos) {
        auto block = getBlock(tilePos.getBlockNum());
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
            auto tile = getTile(tilePos);
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
        dir.normalizeThis();
        int tileIter = cast(int)(ceil(abs(dir.x)) + ceil(abs(dir.y)) + ceil(abs(dir.z)));
        double intersectionTime;
        foreach(tilePos ; TileIterator(start, dir, tileIter, &intersectionTime)) {
            if(intersectionTime > len) {
                return false;
            }
            auto tile = getTile(tilePos);
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
        auto block = getBlock(blockNum); //Dont arbitrarily create blocks. Why would we set lightvals in blocks that dont exist?
        if(!block.valid) {
            return;
        }
        block.setTileLight(tilePos, newVal, isSunLight);

        //notifyTileChange(tilePos);
    }

    void unsafeRemoveTile(TilePos pos) {
        unsafeSetTile(pos, airTile);
    }

    void unsafeSetTile(TilePos pos, Tile tile) {
        //TODO: Think of any reason for or against calling setTile directly here.
        //Like, maybe store it up and do setting in world.update()?
        setTile(pos, tile);
    }

    Tile[TilePos] previousTiles;
    Tile[TilePos] newTiles;

    //Now only called from unsafeSetTile
    private void setTile(TilePos tilePos, const Tile newTile) {
        auto sectorNum = tilePos.getSectorNum();
        SectorXY* sectorXY;
        auto sector = getSector(sectorNum, &sectorXY);

        auto blockNum = tilePos.getBlockNum();
        //auto block = getBlock(blockNum, true);
        auto block = sector.getBlock(blockNum); //No blocks are generated here :)
        BREAK_IF(!block.valid);
        auto oldTile = block.getTile(tilePos);
        block.setTile(tilePos, newTile);

        if(tilePos !in previousTiles) {
            previousTiles[tilePos] = oldTile;
        }
        newTiles[tilePos] = newTile;

//        bool newSolid = !newTile.isAir();
//        bool oldSolid = sector.setSolid(tilePos, newSolid);

        //Update heightmap
        //        auto sectorXY = getSectorXY(SectorXYNum(vec2i(sectorNum.value.x, sectorNum.value.y)));
        auto heightmap = sectorXY.heightmap;
        auto sectRel = tilePos.sectorRel();
        auto heightmapZ = heightmap[sectRel.x, sectRel.y];
        if (heightmapZ == tilePos.value.z) {
            if (newTile.type is TileTypeAir) {
                auto pos = tilePos;
                //Iterate down until find ground, set Z
                while (getTile(pos).type is TileTypeAir) { //Create geometry if we need to
                    pos.value.z -= 1;
                }
                heightmap[sectRel.x, sectRel.y] = pos.value.z;
            }
        } else if (heightmapZ < tilePos.value.z) {
            if (newTile.type !is TileTypeAir) {
                heightmap[sectRel.x, sectRel.y] = tilePos.value.z;
            }
        }

    }

    private void allTilesUpdated() {

        // Lots of malloc here!
        // How much?
        // About 6 meg in initial frame when lots of trees are created / 2012-11-02

        Tile[TilePos] removed;
        Tile[TilePos] added;
        foreach(tp, oldTile ; previousTiles) {
            auto newTile = newTiles[tp];
            if(oldTile == newTile) continue;
            bool oldSolid = !oldTile.isAir;
            bool newSolid = !newTile.isAir;
            if(oldSolid && !newSolid) { //Added air
                removed[tp] = newTile;
            } else if( !oldSolid && newSolid ){ //Removed air
                added[tp] = oldTile;
            }
        }

        removeTile(removed);
        addTile(added);

        foreach(tilePos ; removed.byKey()) {
            notifyTileChange(tilePos);
        }

        previousTiles = null;
        newTiles = null;
    }

    TilePos getTopTilePos(TileXYPos xy) {
        auto rel = xy.sectorRel();
        auto x = rel.x;
        auto y = rel.y;

        auto t = xy.getSectorXYNum();
        SectorXY* xyPtr = t in sectorsXY;
        SectorHeightmap heightmap;
        if(xyPtr !is null) {
            heightmap = xyPtr.heightmap;
        }
        
        if (heightmap is null ) {
            int z = worldMap.getRealTopTilePos(xy);
            auto tp = TilePos(vec3i(xy.value.x, xy.value.y, z));
            return tp;
        }
        assert(heightmap !is null, "heightmap == null! :(");
        auto pos = vec3i(xy.value.x, xy.value.y, heightmap[x, y]);
        return TilePos(pos);
    }

    bool solidNearAirBorder(TilePos min, TilePos max) {
        min.value -= vec3i(1,1,1);
        max.value += vec3i(1,1,1);
        bool solid = false;
        foreach (bn; RangeFromTo(
                    min.getBlockNum().value,
                    max.getBlockNum().value)) {
            auto block = getBlock(BlockNum(bn));
            solid |= block.hasNonAir;
            if (block.hasAir && solid) {
                return true;
            }
        }
        return false;
    }

    bool hasContent(TilePos min, TilePos max) {
        auto sectorMin = min.getSectorNum();
        auto sectorMax = max.getSectorNum();
        foreach (rel; RangeFromTo(sectorMin.value, sectorMax.value)) {
            auto sectorNum = SectorNum(rel);
            auto sectorStartTilePos = sectorNum.toTilePos();
            auto sectorStopTilePos = TilePos(sectorStartTilePos.value + vec3i(SectorSize.x-1, SectorSize.y-1, SectorSize.z-1));
            int minX = std.algorithm.max(sectorStartTilePos.value.x, min.value.x);
            int minY = std.algorithm.max(sectorStartTilePos.value.y, min.value.y);
            int minZ = std.algorithm.max(sectorStartTilePos.value.z, min.value.z);

            int maxX = std.algorithm.min(sectorStopTilePos.value.x, max.value.x);
            int maxY = std.algorithm.min(sectorStopTilePos.value.y, max.value.y);
            int maxZ = std.algorithm.min(sectorStopTilePos.value.z, max.value.z);
            auto sector = getSector(sectorNum);
            if (sector.hasContent(TilePos(vec3i(minX, minY, minZ)), TilePos(vec3i(maxX, maxY, maxZ)))) {
                return true;
            }
        }
        return false;
    }

    void addListener(WorldStateListener listener) {
        listeners ~= listener;
    }
    void removeListener(WorldStateListener listener) {
        remove(listeners, countUntil!q{a is b}(listeners, listener));
        listeners.length -= 1;
    }

    void notifyAddUnit(SectorNum sectorNum, Unit unit) {
        foreach (listener; listeners) {
            listener.onAddUnit(sectorNum, unit);
        }
    }
    void notifyAddEntity(SectorNum sectorNum, Entity entity) {
        foreach (listener; listeners) {
            listener.onAddEntity(sectorNum, entity);
        }
    }

    // Notify sector load here. Try not to modify the state too much!
    void notifySectorLoad(SectorNum sectorNum) {
        if(sectorNum !in activeSectors) {
            msg("Sector no longer of interest after floodfill.");
            return;
        }
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

}

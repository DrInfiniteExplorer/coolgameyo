import std.algorithm, std.range, std.stdio;
import std.container;
import std.exception;
import std.typecons;

import graphics.camera;

import tiletypemanager;
import worldgen.worldgen;
import worldgen.newgen;
public import unit;
import util;

public import pos;
public import worldparts.sector;
public import worldparts.block;
public import worldparts.tile;


// TODO: Refactor so these send world as first parameter,
// and remove the world member from listeners
interface WorldListener {
    void onAddUnit(SectorNum sectorNum, Unit* unit);
    void onSectorLoad(SectorNum sectorNum);
    void onSectorUnload(SectorNum sectorNum);
    void onTileChange(TilePos tilePos);
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

    SectorXY[SectorXYNum] sectorXY;
    Sector[] sectorList;

    WorldGenParams worldGenParams;
    WorldGenerator worldGen;
    bool isServer;  //TODO: How, exactly, does the world function differently if it actually is a server? Find out!

    int unitCount;  //TODO: Is used?

    WorldListener[] listeners;

    TileTypeManager tileTypeManager;

    private alias RedBlackTree!(BlockNum, q{a.value < b.value}) WorkSet;
    WorkSet toFloodFill;
    SectorNum[] floodingSectors;

    this(WorldGenParams params, TileTypeManager tilesys) {
        isServer = true;
        tileTypeManager = tilesys;
        worldGen = new WorldGeneratorOld;
        worldGen = new WorldGeneratorNew;
        worldGenParams = params;
        worldGen.init(worldGenParams, tilesys);

        toFloodFill = new WorkSet;
    }
    
    void destroy() {
        worldGen.destroy();
    }

    void serialize() {  //TODO: Implement serialization
        enforce(0);
        foreach (xy, sectorxy; sectorXY) {
            // write xy markers

            // write heightmap
            foreach (z, sectors; sectorxy.sectors) {
                // write sectors

            }
        }
    }


    void generateBlock(BlockNum blockNum) {
        auto sector = getSector(blockNum.getSectorNum());
        sector.generateBlock(blockNum, worldGen);
    }

    //TODO: Somehow ensure that we're only called from allocateSector
    SectorXY getSectorXY(SectorXYNum xy) {

        if(xy in sectorXY){
            return sectorXY[xy];
        }
        SectorXY ret;
        ret.heightmap = new Heightmap;

        auto p = xy.getTileXYPos();

        auto tileTypeAir = tileTypeManager.idByName("air");
        foreach(relPos ; RangeFromTo(0, SectorSize.x, 0, SectorSize.y, 0, 1)){
            auto tmp = p.value + vec2i(relPos.X, relPos.Y);
            auto posXY = TileXYPos(tmp);
            auto z = worldGen.maxZ(posXY);
            //TODO: Also consider the case where we 
            //      might actually want to move upwards?
            //            ...what?
            while (worldGen.getTile(TilePos(vec3i(
                                posXY.value.X, posXY.value.Y, z))).type
                    is tileTypeAir) {
                z -= 1;
            }

            ret.heightmap[relPos.X, relPos.Y] = z;
        }

        sectorXY[xy] = ret; //Spara det vi skapar, yeah!
        return ret;
    }

    Sector allocateSector(SectorNum sectorNum) {
        auto xy = SectorXYNum(vec2i(sectorNum.value.X, sectorNum.value.Y));
        auto z = sectorNum.value.Z;

        if (xy !in sectorXY) {
            auto ret = getSectorXY(xy);
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

    private void setBlock(BlockNum blockNum, Block newBlock) {
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

    void update(){

        floodFillSome();

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
    }

    // ONLY CALLED FROM CHANGELIST (And some CustomChange-implementations )
    void unsafeMoveUnit(Unit* unit, vec3d destination, uint ticksToArrive){
        unit.destination = UnitPos(destination);
        unit.ticksToArrive = ticksToArrive;
        //Maybe add to list of moving units? Maybe all units are moving?
        //Consider this later. Related to comment in world.update
    }
    
    void unsafeSetTile(TilePos pos, Tile tile) {
        //TODO: Think of any reason for or against calling setTile directly here.
        //Like, maybe store it up and do setting in world.update()?
        setTile(pos, tile);
    }


    private void moveUnit(Unit* unit, UnitPos newPos) {

        moveActivity(unit.pos, newPos);

        unit.pos = newPos;
    }

    //TODO: Implement removeUnit?
    void addUnit(Unit* unit) {
        unitCount += 1;
        auto sectorNum = unit.pos.getSectorNum();

        getSector(sectorNum).addUnit(unit);

        increaseActivity(unit.pos);

        notifyAddUnit(sectorNum, unit);
    }

    Tile getTile(TilePos tilePos, bool createBlock=true,
                                  bool createSector=true) {
        auto block = getBlock(tilePos.getBlockNum(), createBlock, createSector);
        if(!block.valid){
            return INVALID_TILE;
        }
        return block.getTile(tilePos);
    }
    
    //Returns number of iterations nexxxessarrry to intersect a tile.
    //Returns 0 on instant-found or none found.
    int intersectTile(vec3d start, vec3d dir, int tileIter, ref Tile outTile, ref TilePos outPos, ref vec3i Normal) {
        auto tileTypeAir = tileTypeManager.idByName("air");        
        TilePos oldTilePos;
        int cnt;
        foreach(tilePos ; TileIterator(start, dir, tileIter)) {
            cnt++;
            auto tile = getTile(tilePos);            
            scope(exit) oldTilePos = tilePos;
            if (tile.type != tileTypeAir) {
                outPos = tilePos;
                Normal = oldTilePos.value - tilePos.value;
                outTile = tile;
                return cnt;
            }
        }
        return 0;
    }

    //Now only called from unsafeSetTile
    private void setTile(TilePos tilePos, const Tile newTile) {
        //TODO: Make sure penis penis penis, penises.
        //Durr, i mean, make sure to floodfill as well! :)
        auto blockNum = tilePos.getBlockNum();
        auto block = getBlock(blockNum, true, true);
        BREAKPOINT(!block.valid);
        block.setTile(tilePos, newTile);
        //Only works to not set blocknum again, if we already
        // have a block of memory that block.tiles points to;
        // since then we'd be writing into the correct memory.
        // a block is really read-only, but block.tiles if
        // present is read-write.
        setBlock(tilePos.getBlockNum(), block);
        
        auto sectorNum = tilePos.getSectorNum();
        auto sectorXY = getSectorXY(SectorXYNum(vec2i(sectorNum.value.X, sectorNum.value.Y)));
        auto heightmap = sectorXY.heightmap;
        auto sectRel = tilePos.sectorRel();
        auto heightmapZ = heightmap[sectRel.X, sectRel.Y];
        if (heightmapZ == tilePos.value.Z) {
            if (newTile.type is TileTypeAir) {
                auto pos = tilePos;
                //Iterate down until find ground, set Z
                while (getTile(pos).type is TileTypeAir) {
                    pos.value.Z -= 1;
                }
                heightmap[sectRel.X, sectRel.Y] = pos.value.Z;
            }
        } else if (heightmapZ < tilePos.value.Z) {
            if (newTile.type !is TileTypeAir) {
                heightmap[sectRel.X, sectRel.Y] = tilePos.value.Z;
            }
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
        assert(heightmap !is null, "heightmap == null! :(");
        auto pos = vec3i(xy.value.X, xy.value.Y, heightmap[x, y]);
        return TilePos(pos);
    }

    void floodFillSome(int max=1000) {// 10 lol
        //auto sw = StopWatch(AutoStart.yes);

        //int allBlocks = 0;
        //int blockCount = 0;
        //int sparseCount = 0;
        int i = 0;
        while (i < max && !toFloodFill.empty) {
            auto blockNum = toFloodFill.removeAny();

            auto block = getBlock(blockNum);
            if(block.seen) { continue; }
            //allBlocks++;
            if (!block.valid) { continue; }

            //msg("\tFlooding block ", blockNum);

            //blockCount++;
            //msg("blockCount:", blockCount);
            auto blockPos = blockNum.toTilePos();

            block.seen = true;

            scope (exit) setBlock(blockNum, block);

            if (block.sparse) {
                //sparseCount++;
                if (block.sparseTileTransparent) {
                    toFloodFill.insert(BlockNum(blockNum.value + vec3i(1,0,0)));
                    toFloodFill.insert(BlockNum(blockNum.value - vec3i(1,0,0)));
                    toFloodFill.insert(BlockNum(blockNum.value + vec3i(0,1,0)));
                    toFloodFill.insert(BlockNum(blockNum.value - vec3i(0,1,0)));
                    toFloodFill.insert(BlockNum(blockNum.value + vec3i(0,0,1)));
                    toFloodFill.insert(BlockNum(blockNum.value - vec3i(0,0,1)));
                }
                continue;
            }

            foreach (rel;
                    RangeFromTo(0,BlockSize.x,0,BlockSize.y,0,BlockSize.z)) {
                auto tp = TilePos(blockPos.value + rel);
                auto tile = block.getTile(tp);

                scope (exit) block.setTile(tp, tile);

                if (tile.transparent) {
                    tile.seen = true;
                    if (rel.X == 0) {
                        toFloodFill.insert(
                                BlockNum(blockNum.value - vec3i(1,0,0)));
                    } else if (rel.X == BlockSize.x - 1) {
                        toFloodFill.insert(
                                BlockNum(blockNum.value + vec3i(1,0,0)));
                    }
                    if (rel.Y == 0) {
                        toFloodFill.insert(
                                BlockNum(blockNum.value - vec3i(0,1,0)));
                    } else if (rel.Y == BlockSize.y - 1) {
                        toFloodFill.insert(
                                BlockNum(blockNum.value + vec3i(0,1,0)));
                    }
                    if (rel.Z == 0) {
                        toFloodFill.insert(
                                BlockNum(blockNum.value - vec3i(0,0,1)));
                    } else if (rel.Z == BlockSize.z - 1) {
                        toFloodFill.insert(
                                BlockNum(blockNum.value + vec3i(0,0,1)));
                    }
                } else {
                    foreach (npos; neighbors(tp)) {
                        auto neighbor = getTile(npos, true, false);
                        if (neighbor.valid && neighbor.transparent) {
                            tile.seen = true;
                            break;
                        }
                    }
                }
            }
        }
        if (toFloodFill.empty) {
            foreach (sectorNum; floodingSectors) {
                notifySectorLoad(sectorNum);
            }
            floodingSectors.length = 0;
            //floodingSectors.assumeSafeAppend(); // yeaaaaahhhh~~~
        }
        //msg("allBlocks");
        //msg(allBlocks);
        //msg("blockCount");
        //msg(blockCount);
        //msg("sparseCount");
        //msg(sparseCount);

        //msg("Floodfill took ", sw.peek().msecs, " ms to complete");
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


    mixin ActivityHandlerMethods;
}





debug{
    auto activitySize = vec3i(1,1,1);
} else {
    auto activitySize = vec3i(3,3,3);
}

private mixin template ActivityHandlerMethods() {

    void increaseActivity(UnitPos activityLoc) {
        auto sectorNum = activityLoc.getSectorNum();
        auto sector = getSector(sectorNum);

        if (sector.activityCount == 0) {
            addFloodFillPos(activityLoc);
        }
        
        foreach (p; activityRange(sectorNum)) {
            getSector(p).increaseActivity();
        }

        foreach (p; activityRange(sectorNum)) {
            if (getSector(p).activityCount == 1) {
                floodingSectors ~= p;
                foreach (n; neighbors(p)) {
                    auto s = getSector(n, false);

                    if (s && s.activityCount > 1) {
                        addFloodFillWall(p, n);
                    }
                }
            }
        }
    }
    void moveActivity(UnitPos from, UnitPos to) {
        auto a = from.getSectorNum();
        auto b = to.getSectorNum();
        if (a == b) {
            return;
        }

        increaseActivity(to);

        foreach (p; activityRange(from.getSectorNum())) {
            //TODO: Make this work and stuff. Yeah!
            //It now triggers the invariant that says that sectors need to have activity.
            //Should be fixed with activity-linger-timer, which when ending should be handled by
            //serializing sector to disk.
            //getSector(p).decreaseActivity();
        }
    }

    void decreaseActivity(UnitPos activityLoc) {
        assert (0);
    }


    void addFloodFillPos(TilePos pos) {
        toFloodFill.insert(pos.getBlockNum());
    }
    void addFloodFillWall(SectorNum inactive, SectorNum active) {
        foreach (inact, act; getWallBetween(inactive, active)) {
            if (getBlock(act).seen) {
                toFloodFill.insert(inact);
            }
        }
    }
}

auto activityRange(SectorNum base) {
    SectorNum a(vec3i d){
        return SectorNum(d);
    }
    return map!a(RangeFromTo(
            base.value - activitySize/2,
            base.value + activitySize/2 + vec3i(1,1,1)));
}


struct WallBetweenSectors {
    SectorNum inactive, active;

    this(SectorNum _inactive, SectorNum _active) {
        inactive = _inactive;
        active = _active;
    }

    int opApply(scope int delegate(ref BlockNum inact, ref BlockNum act) y) {
        auto delta = inactive.value - active.value;
        assert (delta.getLengthSQ() == 1);

        auto bb = active.toBlockNum.value;

        auto start = vec3i(
                delta.X == 0 ? 0
                : (delta.X == 1 ? BlocksPerSector.x - 1 : 0),
                delta.Y == 0 ? 0
                : (delta.Y == 1 ? BlocksPerSector.y - 1 : 0),
                delta.Z == 0 ? 0
                : (delta.Z == 1 ? BlocksPerSector.z - 1 : 0));
        auto end = vec3i( 
                delta.X == 0 ? BlocksPerSector.x
                : (delta.X == 1 ? BlocksPerSector.x : 1),
                delta.Y == 0 ? BlocksPerSector.y
                : (delta.Y == 1 ? BlocksPerSector.y : 1),
                delta.Z == 0 ? BlocksPerSector.z
                : (delta.Z == 1 ? BlocksPerSector.z : 1));
        BlockNum b(vec3i v) {
            return BlockNum(v);
        }
        auto wall = map!(b)(RangeFromTo(bb+start, bb+end));

        foreach (bn; wall) {
            if (y(BlockNum(bn.value+delta), bn)) return 1;
        }

        return 0;
    }
}

WallBetweenSectors getWallBetween(SectorNum inactive, SectorNum active) {
    return WallBetweenSectors(inactive, active);
}



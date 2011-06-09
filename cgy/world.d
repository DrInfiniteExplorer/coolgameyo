import std.algorithm, std.range, std.stdio;
import std.container;
import std.exception;
import std.typecons;

import graphics.camera;

import tilesystem;
import worldgen;
import unit;
import util;
import pos;


public import worldparts.sector;
public import worldparts.block;
public import worldparts.tile;

interface WorldListener {
    void notifySectorLoad(SectorNum sectorNum);
    void notifySectorUnload(SectorNum sectorNum);
    void notifyTileChange(TilePos tilePos);
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

    WorldGenerator worldGen;
    bool isServer;  //TODO: How, exactly, does the world function differently if it actually is a server? Find out!

    int unitCount;  //TODO: Is used?

    WorldListener[] listeners;

    TileSystem tileSystem;

    private alias RedBlackTree!(BlockNum, q{a.value < b.value}) WorkSet;
    WorkSet toFloodFill;
    SectorNum[] floodingSectors;

    this(TileSystem tilesys) {
        isServer = true;
        tileSystem = tilesys;
        worldGen = new WorldGenerator(tilesys);

        toFloodFill = new WorkSet;
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

        auto tileTypeAir = tileSystem.idByName("air");
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

        writeln("Needs some heightmap generation at ", xy); //Already done :p

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
            auto vel = unit.destination - unit.pos.value;
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
        unit.destination = destination;
        unit.ticksToArrive = ticksToArrive;
        //Maybe add to list of moving units? Maybe all units are moving?
        //Consider this later. Related to comment in world.update
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
    }

    Tile getTile(TilePos tilePos, bool createBlock=true,
                                  bool createSector=true) {
        auto block = getBlock(tilePos.getBlockNum(), createBlock, createSector);
        if(!block.valid){
            return INVALID_TILE;
        }
        return block.getTile(tilePos);
    }

    private void setTile(TilePos tilePos, const Tile newTile) {
        enforce(0, "Called from where?");
        getBlock(tilePos.getBlockNum()).setTile(tilePos, newTile);
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

    //TODO: Turn into timeslicing task
    //TODO: Make it keep track of sectors, in order to make sector-load-notifications.
    void floodFillSome(int max=1000) {// 10 lol
        auto sw = StopWatch(AutoStart.yes);

        int allBlocks = 0;
        int blockCount = 0;
        int sparseCount = 0;
        int i = 0;
        while (i < max && !toFloodFill.empty) {
            auto blockNum = toFloodFill.removeAny();

            auto block = getBlock(blockNum);
            if(block.seen) { continue; }
            allBlocks++;
            if (!block.valid) { continue; }

            writeln("\tFlooding block ", blockNum);

            blockCount++;
            //writeln("blockCount:", blockCount);
            auto blockPos = blockNum.toTilePos();

            block.seen = true;

            scope (exit) setBlock(blockNum, block);

            if (block.sparse) {
                sparseCount++;
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

                if (tile.transparent || tile.halfstep) {
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
                    if (rel.Z == 0 && !tile.halfstep) { //halfsteps only propagate visibility up and to sides
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
                        auto dz = npos.value.Z - tp.value.Z;    //Propagate visibility alll but down for halfsteps.
                        if(neighbor.valid && neighbor.halfstep && dz >= 0){
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
            floodingSectors.assumeSafeAppend(); // yeaaaaahhhh~~~
        }
        writeln("allBlocks");
        writeln(allBlocks);
        writeln("blockCount");
        writeln(blockCount);
        writeln("sparseCount");
        writeln(sparseCount);

        writeln("Floodfill took ", sw.peek().msecs, " ms to complete");
    }


    void addListener(WorldListener listener) {
        listeners ~= listener;
    }
    void removeListener(WorldListener listener) {
        remove(listeners, countUntil!q{a is b}(listeners, listener));
        listeners.length -= 1;
    }

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


    mixin ActivityHandlerMethods;
}




enum activitySize = vec3i(3,3,3);

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
                foreach (n; neighbors(p)) {
                    auto s = getSector(n, false);

                    if (s && s.activityCount > 1) {
                        addFloodFillWall(p, n);
                    }
                }
            }
        }
    }
    void moveActivity(
            UnitPos from, UnitPos to) {

        foreach (p; activityRange(from.getSectorNum())) {
            getSector(p).decreaseActivity();
        }

        foreach (p; activityRange(to.getSectorNum())) {
            getSector(p).increaseActivity();
        }

        foreach (p; activityRange(to.getSectorNum())) {
            if (getSector(p).activityCount == 1) {
                foreach (n; neighbors(p)) {
                    auto s = getSector(n, false);

                    if (s && s.activityCount > 1) {
                        addFloodFillWall(p, n);
                    }
                }
            }
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
    return map!SectorNum(RangeFromTo(
            base.value - activitySize/2,
            base.value + activitySize/2 + vec3i(1,1,1)));
}

struct WallBetweenSectors {
    SectorNum inactive, active;


    int opApply(scope int delegate(ref BlockNum inact, ref BlockNum act) y) {
        auto delta = inactive.value - active.value;
        assert (delta.getLength() == 1);

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
        auto wall = map!BlockNum(RangeFromTo(bb+start, bb+end));

        foreach (bn; wall) {
            if (y(BlockNum(bn.value+delta), bn)) return 1;
        }

        return 0;
    }
}

WallBetweenSectors getWallBetween(SectorNum inactive, SectorNum active) {
    return WallBetweenSectors(inactive, active);
}



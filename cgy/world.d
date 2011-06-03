import std.algorithm, std.range, std.stdio;
import std.container;
import std.exception;

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

class World {

    static final class Heightmap {
        int[SectorSize.y][SectorSize.x] heightmap;

        void opIndexAssign(int val, size_t x, size_t y) {
            heightmap[x][y] = val;
        }
        ref int opIndex(size_t x, size_t y) {
            return heightmap[x][y];
        }
        this() {};
    }

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

    this(TileSystem tilesys) {
        isServer = true;
        tileSystem = tilesys;
        worldGen = new WorldGenerator(tilesys);
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
            auto posXY = tileXYPos(tmp);
            auto z = worldGen.maxZ(posXY);
            //TODO: Also consider the case where we 
            //      might actually want to move upwards?
            //            ...what?
            while (worldGen.getTile(tilePos(posXY, z)).type is tileTypeAir) {
                z -= 1;
            }

            ret.heightmap[relPos.X, relPos.Y] = z;
        }

        writeln("Needs some heightmap generation at ", xy); //Already done :p

        sectorXY[xy] = ret; //Spara det vi skapar, yeah!
        return ret;
    }

    Sector allocateSector(SectorNum sectorNum) {
        auto xy = sectorXYNum(vec2i(sectorNum.value.X, sectorNum.value.Y));
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
        auto before = unit.pos.tilePos();
        auto after = newPos.tilePos();

        unit.pos = newPos;

        auto secDiff = sectorNum(after.getSectorNum().value - before.getSectorNum().value);
        writeln(before, after);
        writeln(after.getSectorNum(), before.getSectorNum());
        writeln(secDiff);

        if (secDiff.value == vec3i(0,0,0)) return;

        enforce(secDiff.value.getLengthSQ() <= 3, "Unit moving faster than we can possibly handle!!");

        Direction dir;

        if (secDiff.value.X < 0) dir |= Direction.west;
        else if (secDiff.value.X > 0) dir |= Direction.east;

        if (secDiff.value.Y < 0) dir |= Direction.south;
        else if (secDiff.value.Y > 0) dir |= Direction.north;

        if (secDiff.value.Z < 0) dir |= Direction.down;
        else if (secDiff.value.Z > 0) dir |= Direction.up;

        enforce(0, "Implement floodfilling duh!");

        // Make sure to increase activity in the good sectors and decrese4 int
        // the blahbl ah old ones we leaft blah ;;;
    }

    //TODO: Implement removeUnit?
    void addUnit(Unit* unit) {
        unitCount += 1;
        auto sectorNum = unit.pos.tilePos.getSectorNum();

        getSector(sectorNum).addUnit(unit);

        //Range +-2

        RangeFromTo range;
        range = RangeFromTo(-2,3,-2,3,-2,3);
//        range = RangeFromTo(-1,2,-1,2,-1,2); //Make it faster in debyyyyg!!
        range = RangeFromTo(0,1,0,1,0,1); //Make it faster in debyyyyg!!

        //TODO: Consider moving functionality to moveUnit, and calling that from here?
        foreach (dpos; range) {
            auto pos = unit.pos.tilePos.getSectorNum();
            getSector(SectorNum(pos.value + dpos)).increaseActivity();
        }
        foreach (dpos; range) {
            auto pos = unit.pos.tilePos.getSectorNum();
            pos.value += dpos;
            auto sector = getSector(pos);
            if (sector.activityCount == 1) {
                if (unit.pos.tilePos.getSectorNum() == sectorNum) {
                    writeln("wherp");
                    floodFillVisibility(/*sector, ??? */unit.pos.tilePos);
                    writeln("zerp");
                } else {
                    assert(0, "implement stuff below");
                    //floodFillVisibility(/* sector, ??? */Direction.all); // Derp?
                }
            }
        }

        //TODO: We need to turn floodfilling into a timeslicing, taskable thing, and only notify of sector load after floodfill is done.

        //MAKE FIX, NOT ONE LOAD FOR EVERY UNIT!!
        //Keep small array/map of which are just-now-loaded?
        foreach (dpos; range) { //We want to build geometry etc only after all relevant data has been loaded.
            auto pos = unit.pos.tilePos.getSectorNum();
            pos.value.X += dpos.X;
            pos.value.Y += dpos.Y;
            pos.value.Z += dpos.Z;
            auto sector = getSector(pos);
            notifySectorLoad(sector.sectorNum);
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
        return tilePos(pos);
    }
    private alias RedBlackTree!(BlockNum, q{a.value < b.value}) WorkSet;

    void floodFillVisibility(const TileXYPos xyStart) {
        auto startPos = getTopTilePos(xyStart);
        startPos.value += vec3i(0,0,1);
        floodFillVisibility(startPos);
    }

    void floodFillVisibility(SectorNum sectorNum, Direction dir) {
        auto work = new WorkSet;

        if (dir & Direction.north) {
            auto range = RangeFromTo(0, BlocksPerSector.x,
                    0, 1,
                    0, BlocksPerSector.z);
            foreach (rel; range) {
                auto abs = sectorNum.toBlockNum().value + rel;
                if (getBlock(BlockNum(abs + vec3i(0, -1, 0))).seen) {
                    work.insert(BlockNum(abs));
                }
            }
        }
        if (dir & Direction.south) {
            auto range = RangeFromTo(0, BlocksPerSector.x,
                    BlocksPerSector.y - 1, BlocksPerSector.y,
                    0, BlocksPerSector.z);
            foreach (rel; range) {
                auto abs = sectorNum.toBlockNum().value + rel;
                if (getBlock(BlockNum(abs + vec3i(0, 1, 0))).seen) {
                    work.insert(BlockNum(abs));
                }
            }
        }
        if (dir & Direction.west) {
            auto range = RangeFromTo(0, 1,
                    0, BlocksPerSector.y,
                    0, BlocksPerSector.z);
            foreach (rel; range) {
                auto abs = sectorNum.toBlockNum().value + rel;
                if (getBlock(BlockNum(abs + vec3i(-1, 0, 0))).seen) {
                    work.insert(BlockNum(abs));
                }
            }
        }
        if (dir & Direction.east) {
            auto range = RangeFromTo(BlocksPerSector.x-1, BlocksPerSector.x,
                    0, BlocksPerSector.y,
                    0, BlocksPerSector.z);
            foreach (rel; range) {
                auto abs = sectorNum.toBlockNum().value + rel;
                if (getBlock(BlockNum(abs + vec3i(1, 0, 0))).seen) {
                    work.insert(BlockNum(abs));
                }
            }
        }
        if (dir & Direction.up) {
            auto range = RangeFromTo(0, BlocksPerSector.x,
                    0, BlocksPerSector.y,
                    0, 1);
            foreach (rel; range) {
                auto abs = sectorNum.toBlockNum().value + rel;
                if (getBlock(BlockNum(abs + vec3i(0, 0, -1))).seen) {
                    work.insert(BlockNum(abs));
                }
            }
        }
        if (dir & Direction.down) {
            auto range = RangeFromTo(0, BlocksPerSector.x,
                    0, BlocksPerSector.y,
                    BlocksPerSector.z - 1, BlocksPerSector.z);
            foreach (rel; range) {
                auto abs = sectorNum.toBlockNum().value + rel;
                if (getBlock(BlockNum(abs + vec3i(0, 0, 1))).seen) {
                    work.insert(BlockNum(abs));
                }
            }
        }
        floodFillVisibilityImpl(work);
    }

    void floodFillVisibility(const TilePos startPos) {
        floodFillVisibilityImpl(new WorkSet(startPos.getBlockNum()));
    }

    //TODO: Turn into timeslicing task
    //TODO: Make it keep track of sectors, in order to make sector-load-notifications.
    private void floodFillVisibilityImpl(WorkSet work) {
        StopWatch sw;
        sw.start();

        int allBlocks = 0;
        int blockCount = 0;
        int sparseCount = 0;
        while (!work.empty) {
            auto blockNum = work.removeAny();

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
                    work.insert(.blockNum(blockNum.value + vec3i(1, 0, 0)));
                    work.insert(.blockNum(blockNum.value - vec3i(1, 0, 0)));
                    work.insert(.blockNum(blockNum.value + vec3i(0, 1, 0)));
                    work.insert(.blockNum(blockNum.value - vec3i(0, 1, 0)));
                    work.insert(.blockNum(blockNum.value + vec3i(0, 0, 1)));
                    work.insert(.blockNum(blockNum.value - vec3i(0, 0, 1)));
                }
                continue;
            }

            foreach (rel;
                    RangeFromTo(0,BlockSize.x,0,BlockSize.y,0,BlockSize.z)) {
                auto tp = tilePos(blockPos.value + rel);
                auto tile = block.getTile(tp);

                scope (exit) block.setTile(tp, tile);

                if (tile.transparent || tile.halfstep) {
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
                    if (rel.Z == 0 && !tile.halfstep) { //halfsteps only propagate visibility up and to sides
                        work.insert(.blockNum(blockNum.value - vec3i(0,0,1)));
                    } else if (rel.Z == BlockSize.z - 1) {
                        work.insert(.blockNum(blockNum.value + vec3i(0,0,1)));
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
        writeln("allBlocks");
        writeln(allBlocks);
        writeln("blockCount");
        writeln(blockCount);
        writeln("sparseCount");
        writeln(sparseCount);

        writeln("Floodfill took ", sw.peek().msecs, " ms to complete");
        assert (0);
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





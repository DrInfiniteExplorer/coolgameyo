import std.algorithm, std.range, std.stdio;
import std.container;
import std.exception;

import worldgen;
import unit;
import camera;
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
    
    TileType[] tileTypes;

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
            while (worldGen.getTile(tilePos(posXY, z)).type == TileTypeAir) {
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

    //Sector[] lock() { return sectorList; } used by anithing?
    
    
    void update(){
        
    }
    
    Unit*[] getVisibleUnits(Camera camera){
        Unit*[] units;
        foreach(sector; sectorList){
            foreach(unit; sector.units){
                if(camera.inFrustum(unit)){
                    units ~= unit;
                }
            }
        }
        return units;
    }

    void moveUnit(Unit* unit) {
        assert(0, "Implement");
    }
    
    void moveUnit(Unit* unit, UnitPos newPos) {
        auto before = unit.pos.tilePos();
        auto after = newPos.tilePos();

        auto secDiff = sectorNum(after.getSectorNum().value - before.getSectorNum().value);

        if (secDiff.value == vec3i(0,0,0)) return;

        assert (secDiff.value.getLengthSQ() <= 3);

        Direction dir;

        if (secDiff.value.X < 0) dir |= Direction.west;
        else if (secDiff.value.X > 0) dir |= Direction.east;

        if (secDiff.value.Y < 0) dir |= Direction.south;
        else if (secDiff.value.Y > 0) dir |= Direction.north;

        if (secDiff.value.Z < 0) dir |= Direction.down;
        else if (secDiff.value.Z > 0) dir |= Direction.up;

        assert (0);

        // Make sure to increase activity in the good sectors and decrese4 int
        // the blahbl ah old ones we leaft blah ;;;
    }

    void addUnit(Unit* unit) {
        unitCount += 1;
        auto sectorNum = unit.pos.tilePos.getSectorNum();
        { //Scope to prevent shadowing of variable name sector. todo: plol can think of other name for variables? (his codeee)
            auto sector = getSector(sectorNum);
            sector.addUnit(unit);
        }

        //Range +-2

        auto range = RangeFromTo(-2,3,-2,3,-2,3);
        //debug
        {
            range = RangeFromTo(0,1,0,1,0,1); //Make it faster in debyyyyg!!
        }

        foreach (dpos; range) {
            auto pos = unit.pos.tilePos.getSectorNum();
            pos.value.X += dpos.X;
            pos.value.Y += dpos.Y;
            pos.value.Z += dpos.Z;
            auto sector = getSector(pos);
            sector.increaseActivity();
            if (sector.activityCount == 1) {
                if (unit.pos.tilePos.getSectorNum() == sectorNum) {
                    floodFillVisibility(/*sector, ??? */unit.pos.tilePos);
                } else {
                    assert(0, "implement stuff below");
                    //floodFillVisibility(/* sector, ??? */Direction.all); // Derp?
                }
                notifySectorLoad(sector.sectorNum);
            }
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
        auto pos = vec3i(xy.value.X, xy.value.Y, (*heightmapPtr)[x][y]);
        return tilePos(pos);        
    }
    private alias RedBlackTree!(BlockNum, q{a.value < b.value}) WorkSet;

    void floodFillVisibility(const TileXYPos xyStart) {
        auto startPos = getTopTilePos(xyStart);
        startPos.value += vec3i(0,0,1);
        floodFillVisibility(startPos);
    }

    void floodFillVisibility(SectorNum sectorNum, Direction dir) {
        BlockNum[] wtf;
        auto work = WorkSet(wtf);

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
        floodFillVisibilityImpl(WorkSet(startPos.getBlockNum()));
    }

    private void floodFillVisibilityImpl(WorkSet work) {
        
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

                if (tile.transparent) {
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
                        if (neighbor.valid && neighbor.transparent) {
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

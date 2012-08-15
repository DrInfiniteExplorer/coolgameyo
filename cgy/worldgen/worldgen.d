
module worldgen.worldgen;

import std.algorithm;
import std.c.process;
import std.conv;
import std.exception;
import std.math;
import std.random;
import std.typecons;


import graphics.texture;
import graphics.debugging;
import light;
import pos;
import statistics;
import util.rangefromto;
import util.util;

import worldgen.maps;

import random.random;
import random.randsource;
import random.gradientnoise;




/*

layer5: 256 mil

layer4: 64 mil

layer3: 16 mil

layer2: 4 mil

layer1: 10km², 1mil

*/

//alias ValueMap2D!(double, false) ValueMap;



//alias double[ptPerLayer][ptPerLayer] Map;



mixin template WorldGenerator() {

    TileTypeManager sys;

    void initWorldGenerator(TileTypeManager tileTypeManager) {
        sys = tileTypeManager;
    }

    void fillSector(Sector sector, SectorHeightmap heightmap) {

        double[SectorSize.x][SectorSize.y] heightValues;
        auto sectorStart = sector.getSectorNum().toTileXYPos();
        foreach(int x, int y ; Range2D(vec2i(0, 0), vec2i(SectorSize.x, SectorSize.y))) {
            heightValues[y][x] = getValueInterpolated(1, TileXYPos(sectorStart.value + vec2i(x, y)));
        }

        auto heightmap = heightmap.getMaxPerBlock();

        auto sectorNum = sector.getSectorNum();
        auto abs = sectorNum.toBlockNum().value;
        Block_t tempBlock = Block.allocBlock();
        foreach(rel ; RangeFromTo( 0, BlocksPerSector.x - 1, 0, BlocksPerSector.y - 1, 0, BlocksPerSector.z - 1)) {
            auto blockNum = BlockNum(abs + rel);
            if(blockNum.toTilePos().value.Z > heightmap[rel.Y][rel.X]) {
                sector.makeAirBlock(blockNum);
                continue;
            }
            Block_t block = tempBlock;
            block.blockNum = blockNum;
            if(fillBlockInternal(&block, heightValues)) {
                tempBlock = block.allocBlock();
            }
            sector.unsafe_setBlock(block);
        }
        tempBlock.free();
    }

    //Returns true if the block is solid, false if it is sparse.
    //It is the callers responsibility to make sure the block is free'd
    private bool fillBlockInternal(Block block, ref double[SectorSize.x][SectorSize.y] groundValueMap) {
        auto blockNum = block.blockNum;
        auto blockRel = blockNum.rel();
        auto tp0 = blockNum.toTilePos();

        int tileOffset_x = blockRel.X * BlockSize.x;
        int tileOffset_y = blockRel.Y * BlockSize.y;

        block.hasAir = false;
        block.hasNonAir = false;

        bool homogenous = true;
        bool first = true;
        foreach (relPos; RangeFromTo (0, BlockSize.x-1,
                    0, BlockSize.y-1, 0, BlockSize.z-1)) {
            auto tp = tp0;
            tp.value += relPos;
            auto groundValue = groundValueMap[tileOffset_y + relPos.Y][tileOffset_x + relPos.X];
            auto tile = getTile(tp, groundValue);
            block.tiles.tiles[relPos.Z][relPos.Y][relPos.X] = tile;

            if (first) {
                first = false;
                block.sparseTileType = tile.type;
                block.sunLightVal = tile.sunLightValue;
            }
            if (block.sparseTileType != tile.type ||
                block.sunLightVal != tile.sunLightValue) {
                homogenous = false;
            }
            if (tile.type == TileTypeAir) {
                block.hasAir = true;
            } else {
                block.hasNonAir = true;
            }
        }
        if (homogenous) {
            //block.free();
            //Block.free(block);
            block.tiles = null;
            block.sparse = true;
            return false;
        }

        return true;
    }

    Tile getTile(TilePos pos) {
        BREAKPOINT;
        return getTile(pos,
                getValueInterpolated(1, TileXYPos(pos)));
    }

    Tile getTile(TilePos pos, double z) {

        TileFlags flags = cast(TileFlags)(TileFlags.valid);
        if(! isInsideWorld(pos)) {
            return Tile(TileTypeAir, flags);
        }
        if(pos.value.Z > z) {
            auto tile = Tile(TileTypeAir, flags);
            tile.sunLightValue = 15;
            return tile;
        }

        //For now just use basic climate types to determine tile types.
//        auto area = getArea(pos.toTileXYPos());
  //      getBasicTileType(area);

        return Tile(TileTypeAir+1, flags);
    }

    auto getBasicTileType(Area area) {
        
    }

    long worldRadius = mapScale[5]/2;
    long worldRadiusSquare = (cast(long)mapScale[5]/2) ^^2;
    bool isInsideWorld(TilePos pos) {
        if(pos.value.X < 0 || pos.value.X >= worldSize ||
           pos.value.Y < 0 || pos.value.Y >= worldSize) {
            return false;
        }
        return true;
    } 

    //This returns a pessimistiv top value, there may be air-tiles below but no solid above.
    int maxZ(TileXYPos xyPos) {
        auto z = getValueInterpolated(1, xyPos);
        return cast(int)ceil(z);
    }

    //This returns the real, actual top tile pos.
    int getRealTopTilePos(TileXYPos xyPos) {
        return maxZ(xyPos);
    }

    double getHeight01(TilePos t) {
        return cast(double)maxZ(TileXYPos(t)) / 500.0;
    }

}





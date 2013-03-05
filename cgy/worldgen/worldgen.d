
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
import util.pos;
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

    int randomNumber = 0;

    TileTypeManager tileSys;

    void fillSector(Sector sector, SectorHeightmap heightmap) {

        double[SectorSize.x][SectorSize.y] heightValues;
        auto sectorStart = sector.getSectorNum().toTileXYPos();
        foreach(int x, int y ; Range2D(vec2i(0, 0), vec2i(SectorSize.x, SectorSize.y))) {
            auto pos = TileXYPos(sectorStart.value + vec2i(x, y));
            heightValues[y][x] = heightMaps.getHeight(pos); //getValueInterpolated(1, ));
        }

        auto heightmap = heightmap.getMaxPerBlock();

        auto sectorNum = sector.getSectorNum();
        auto abs = sectorNum.toBlockNum().value;
        Block_t tempBlock = Block.allocBlock();
        foreach(rel ; RangeFromTo( 0, BlocksPerSector.x - 1, 0, BlocksPerSector.y - 1, 0, BlocksPerSector.z - 1)) {
            auto blockNum = BlockNum(abs + rel);
            if(blockNum.toTilePos().value.z > heightmap[rel.y][rel.x]) {
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

        int tileOffset_x = blockRel.x * BlockSize.x;
        int tileOffset_y = blockRel.y * BlockSize.y;

        block.hasAir = false;
        block.hasNonAir = false;

        bool homogenous = true;
        bool first = true;
        foreach (relPos; RangeFromTo (  0, BlockSize.x-1,
                                        0, BlockSize.y-1, 
                                        0, BlockSize.z-1)) {
            auto tp = tp0;
            tp.value += relPos;
            auto groundValue = groundValueMap[tileOffset_y + relPos.y][tileOffset_x + relPos.x];
            auto tile = getTile(tp, groundValue);
            block.tiles.tiles[relPos.z][relPos.y][relPos.x] = tile;

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
        auto height = heightMaps.getHeight(TileXYPos(pos));
        return getTile(pos, height);
    }

    Tile getTile(TilePos pos, double z) {

        TileFlags flags = cast(TileFlags)(TileFlags.valid);
        if(! isInsideWorld(pos)) {
            return Tile(TileTypeAir, flags);
        }
        if(pos.value.z > z) {
            auto tile = Tile(TileTypeAir, flags);
            tile.sunLightValue = 15;
            return tile;
        }

        //For now just use basic climate types to determine tile types.
        auto tileType = getBasicTileType();

        return Tile(tileType, flags);
    }
    ushort getBasicTileType() {
        randomNumber++;

        auto group = tileSys.getGroup("genericGrass");
        int idx = randomNumber % group.length;
        auto id = group[idx].id;
        return id;
    }

    long worldRadius = worldSize;
    long worldRadiusSquare = (cast(long)worldSize) ^^2;
    bool isInsideWorld(TilePos pos) {
        if(pos.value.x < 0 || pos.value.x >= worldSize ||
           pos.value.y < 0 || pos.value.y >= worldSize) {
            return false;
        }
        return true;
    } 

    //This returns a pessimistiv top value, there may be air-tiles below but no solid above.
    int maxZ(TileXYPos xyPos) {
        auto height = heightMaps.getHeight(xyPos);
        return cast(int)ceil(height);
    }

    //This returns the real, actual top tile pos.
    int getRealTopTilePos(TileXYPos xyPos) {
        return maxZ(xyPos);
    }

    float getApproxHeight(TileXYPos pos, int level) {
        pos.value.x = clamp(pos.value.x, 0, worldSize-sampleIntervall);
        pos.value.y = clamp(pos.value.y, 0, worldSize-sampleIntervall);
        auto height = heightMaps.getHeight!false(pos);
        return cast(int)ceil(height);
    }

}





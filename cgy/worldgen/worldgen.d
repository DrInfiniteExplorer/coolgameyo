
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

    auto getHeight(TileXYPos pos) {
        //return heightMaps.getHeight!false(pos);
        return heightMaps.getHeight!true(pos);
    }
    auto getSoil(TileXYPos pos) {
        //return heightMaps.getSoil!false(pos);
        return heightMaps.getSoil!true(pos);
    }

    void fillSector(Sector sector, SectorHeightmap _heightmap) {

        double[SectorSize.x][SectorSize.y] heightValues;
        double[SectorSize.x][SectorSize.y] soilValues;
        auto sectorStart = sector.getSectorNum().toTileXYPos();
        foreach(int x, int y ; Range2D(vec2i(0, 0), vec2i(SectorSize.x, SectorSize.y))) {
            auto pos = TileXYPos(sectorStart.value + vec2i(x, y));
            heightValues[y][x] = getHeight(pos); //getValueInterpolated(1, ));
            soilValues[y][x] = getSoil(pos); //getValueInterpolated(1, ));
        }

        auto heightmap = _heightmap.getMaxPerBlock();

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
            if(fillBlockInternal(&block, heightValues, soilValues)) {
                tempBlock = block.allocBlock();
            }
            sector.unsafe_setBlock(block);
        }
        tempBlock.free();
    }

    //Returns true if the block is solid, false if it is sparse.
    //It is the callers responsibility to make sure the block is free'd
    private bool fillBlockInternal(Block block,
                                   ref double[SectorSize.x][SectorSize.y] heightMap,
                                   ref double[SectorSize.x][SectorSize.y] soilMap) {
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
            auto heightValue = heightMap[tileOffset_y + relPos.y][tileOffset_x + relPos.x];
            auto soilValue = soilMap[tileOffset_y + relPos.y][tileOffset_x + relPos.x];
            auto tile = getTile(tp, heightValue, soilValue);
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
        auto height = getHeight(TileXYPos(pos));
        auto soil = getHeight(TileXYPos(pos));
        return getTile(pos, height, soil);
    }

    Tile getTile(TilePos pos, double heightValue, double soilValue) {

        TileFlags flags = cast(TileFlags)(TileFlags.valid);
        if(! isInsideWorld(pos)) {
            return Tile(TileTypeAir, flags);
        }
        float distanceAboveGround = pos.value.z - (heightValue + soilValue);
        if(distanceAboveGround > 0) {
            auto tile = Tile(TileTypeAir, flags);
            tile.sunLightValue = 15;
            return tile;
        }
        float distanceBelowGround = -distanceAboveGround;
        if(pos.value.z > heightValue) { // Soil tile, determine soil type yeah!
            if(distanceBelowGround < 1) {
                auto tileType = getBasicTileType("genericGrass");
                return Tile(tileType, flags);
            } else {
                auto tileType = getBasicTileType("genericSoil");
                return Tile(tileType, flags);
            }
        }
        // Below soil. Lets make it interesting!

        //auto tileType = getBasicTileType!"genericStone"();
        //return Tile(tileType, flags);

        int x = pos.value.x;
        int y = pos.value.y;
        int z = pos.value.z;
        z = fastFloor(z - heightMaps.getOriginalHeight(pos.value.v2)); // Depth under 'normal' generated world
        int materialNum = getStrataNum(x, y, z);
        BREAK_IF(materialNum < 0);
        BREAK_IF(materialNum >= materials.length);
        auto material = materials[materialNum];

        auto tileType = getBasicTileType(material.name);
        return Tile(tileType, flags);


    }
    ushort getBasicTileType(string _group) { 
        randomNumber++;

        auto group = tileSys.getGroup(_group);
        int idx = randomNumber % cast(int)group.length;
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
        if(!isInsideWorld(xyPos.toTilePos(0))) return -500;
        auto height = getHeight(xyPos);
        auto soil = getSoil(xyPos);
        return cast(int)ceil(height + soil);
    }

    //This returns the real, actual top tile pos.
    int getRealTopTilePos(TileXYPos xyPos) {
        return maxZ(xyPos);
    }

    float getApproxHeight(TileXYPos pos, int level) {
        pos.value.x = clamp(pos.value.x, 0, worldSize-SampleIntervall);
        pos.value.y = clamp(pos.value.y, 0, worldSize-SampleIntervall);
        auto height = heightMaps.getHeight!false(pos);
        auto soil = heightMaps.getSoil!false(pos);
        return cast(int)ceil(height + soil);
    }

}





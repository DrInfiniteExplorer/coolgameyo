
module worldgen.worldgen;

import std.algorithm;
import core.stdc.stdlib; //std.c.process;
import std.conv;
import std.exception;
import std.math;
import std.random;
import std.range : chain;
import std.typecons;


import graphics.texture;
import graphics.debugging;
import light;
import cgy.util.pos;
import cgy.util.statistics;
import cgy.util.rangefromto;
import cgy.util.util;

import worldgen.maps;

import random.random;
import random.randsource;
import random.gradientnoise;


mixin template WorldGenerator() {

    int randomNumber = 0;

    auto getHeight(TileXYPos pos) {
        //return heightMaps.getHeight!false(pos);
        return heightMaps.getHeight!true(pos);
    }
    auto getSoil(TileXYPos pos) {
        //return heightMaps.getSoil!false(pos);
        return heightMaps.getSoil!true(pos);
    }
    auto getWater(TileXYPos pos) {
        //return heightMaps.getSoil!false(pos);
        return heightMaps.getWater!true(pos);
    }

    private void setTile(Sector s, TilePos tp, Tile tile) {
        if(s.getSectorNum() != tp.getSectorNum()) return;
        auto block = s.getBlock(tp.getBlockNum);
        block.setTile(tp, tile);
    }

    void drawRoads(Sector sector,
                   ref double[SectorSize.x][SectorSize.y] heightValues,
                   ref double[SectorSize.x][SectorSize.y] soilValues
                   ) {
        // Now the fun part!
        // Place roads in the world! :D
        // Yeah!
        auto sectorNum = sector.getSectorNum();
        auto sectorStart = sectorNum.toTileXYPos();
        auto roads = getRoadsInSector(sectorNum);

        vec2i sectorCenter = sectorStart.value + vec2i(SectorSize.x / 2, SectorSize.y / 2);
        enum closeByLimit = SectorSize.x ^^ 2 + SectorSize.y ^^ 2;
        bool closeByFilter(vec2i tilePos) {
            return tilePos.getDistanceSQ(sectorCenter) < closeByLimit;
        }

        int getHeight(vec2i tp) {
            if(tp.v3(sectorNum.toTilePos.value.z).TilePos.getSectorNum() != sectorNum) return -1;
            auto rel = tp.TileXYPos.sectorRel();
            return cast(int)(heightValues[rel.y][rel.x] + soilValues[rel.y][rel.x]);
        }

        TileFlags flags = cast(TileFlags)(TileFlags.valid);
        foreach(road ; roads) {
            // Builds a pile of gravel at endpoints.
            auto derp = road.a.pos*25;
            auto asdf = derp.v3(getHeight(derp));
            if( asdf.TilePos.getSectorNum() == sectorNum) {
                auto tp = asdf.TilePos;
                auto tileType = getBasicTileType("genericGravel");
                auto tile = Tile(tileType, flags);
                foreach(i ; 0 .. 10) {
                    setTile(sector, tp, tile);
                    tp.value.z++;
                }
            }

            // Builds road.
            auto aPos = makeStackArray(road.a.pos);
            auto bPos = makeStackArray(road.b.pos);
            auto sourcePoints = chain(aPos[], road.points, bPos[]);
            vec2i[] roadTilePos = array(filter!closeByFilter(map!"a*25"(sourcePoints)));
            vec2d[] points;
            points.length = roadTilePos.length;
            //points[] = vec2d(12.5);
            points.convertArray(roadTilePos);

            alias Interpolate!(CubicInter, false, double, vec2d) interpolate4;
            alias Interpolate!(lerp, false, double, vec2d) interpolate2;

            enum int stepsPerPoint = 50;
            enum int roadWidthSteps = 10;
            enum double roadWidth = 3;
            vec2d prevPos;
            foreach(idx ; 0 .. points.length * stepsPerPoint) {
                double t = idx / cast(double)(points.length * stepsPerPoint);
                vec2d pos;
                if(points.length >= 4) {
                    pos = interpolate4(t, points);
                } else {
                    pos = interpolate2(t, points);
                }
                scope(exit) prevPos = pos;
                scope(exit) {
                    auto tp = pos.v3(getHeight(pos.convert!int)).convert!int.TilePos;
                    auto tileType = getBasicTileType("genericGravel");
                    auto tile = Tile(tileType, flags);
                    setTile(sector, tp, tile);
                    }
                if(idx == 0) continue;
                int centerPosHeight = getHeight(pos.convert!int);
                if(centerPosHeight == -1) continue; // Outside of sector.
                vec2d normal = (pos-prevPos);
                normal = normal.rotate90();
                normal.normalizeThis();
                foreach(orthoIdx ; -roadWidthSteps/2 .. roadWidthSteps/2) {
                    double orthoLength = (orthoIdx / cast(double)roadWidthSteps) * roadWidth;
                    vec2d tpPos = pos + normal * orthoLength;
                    vec2i tp2 = tpPos.convert!int;
                    vec3i tp3 = tp2.v3(centerPosHeight);
                    auto tileType = getBasicTileType("genericGravel");
                    auto tile = Tile(tileType, flags);
                    setTile(sector, TilePos(tp3), tile);

                    int thisZ = getHeight(tp2);
                    if(thisZ > centerPosHeight) {
                        foreach(z ;  centerPosHeight+1 .. thisZ+1) {
                            tp3 = tp2.v3(z);
                            tile = airTile;
                            tile.sunLightVal = 15;
                            setTile(sector, TilePos(tp3), tile);
                        }
                    } else if(thisZ < centerPosHeight) {
                        foreach(z ;  thisZ .. centerPosHeight) {
                            tp3 = tp2.v3(z);
                            tileType = getBasicTileType("genericDirt");
                            tile = Tile(tileType, flags);
                            setTile(sector, TilePos(tp3), tile);
                        }
                    }

                }
            }
        }
    }

    void fillSector(Sector sector, SectorHeightmap _heightmap) {

        double[SectorSize.x][SectorSize.y] heightValues;
        double[SectorSize.x][SectorSize.y] soilValues;
        double[SectorSize.x][SectorSize.y] waterValues;
        auto sectorNum = sector.getSectorNum();
        auto sectorStart = sectorNum.toTileXYPos();
        foreach(int x, int y ; Range2D(vec2i(0, 0), vec2i(SectorSize.x, SectorSize.y))) {
            auto pos = TileXYPos(sectorStart.value + vec2i(x, y));
            heightValues[y][x] = getHeight(pos); //getValueInterpolated(1, ));
            soilValues[y][x] = getSoil(pos); //getValueInterpolated(1, ));
            waterValues[y][x] = getWater(pos); //getValueInterpolated(1, ));
        }

        auto heightmap = _heightmap.getMaxPerBlock();

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
            if(fillBlockInternal(&block, heightValues, soilValues, waterValues)) {
                tempBlock = block.allocBlock();
            }
            sector.unsafe_setBlock(block);
        }
        tempBlock.free();

        drawRoads(sector, heightValues, soilValues);

  
    }

    //Returns true if the block is solid, false if it is sparse.
    //It is the callers responsibility to make sure the block is free'd
    private bool fillBlockInternal(Block block,
                                   ref double[SectorSize.x][SectorSize.y] heightMap,
                                   ref double[SectorSize.x][SectorSize.y] soilMap,
                                   ref double[SectorSize.x][SectorSize.y] waterMap) {
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
            auto waterValue = waterMap[tileOffset_y + relPos.y][tileOffset_x + relPos.x];
            auto tile = getTileInternal(tp, heightValue, soilValue, waterValue);
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

    // Returns the tile which would be placed when nothing affects the world.
    // Ie no roads, no cities, no nothing.
    // Care to handle these thingies must be taken before calling this function.
    // Yeah. Either that, or replace the tiles after they are generated. Yeah.
    private Tile getTileInternal(TilePos pos, double heightValue, double soilValue, double waterValue) {

        TileFlags flags = cast(TileFlags)(TileFlags.valid);
        if(! isInsideWorld(pos)) {
            return Tile(TileTypeAir, flags, 0);
        }
        float distanceAboveGround = pos.value.z - (heightValue + soilValue);
        if(distanceAboveGround > 0) {
            if(distanceAboveGround > waterValue) {
                auto tile = Tile(TileTypeAir, flags, 0);
                tile.sunLightValue = 15;
                return tile;
            } else {
                auto tileType = getBasicTileType("genericLiquid");
                auto tileTypeId = tileType.id;
                auto tileTypeHealth = tileType.strength;
                auto  tile = Tile(tileType, flags);
                tile.sunLightValue = 15;
                return tile;
            }
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
        z = fastFloor(z - heightMaps.getOriginalHeight(pos.value.v2.TileXYPos)); // Depth under 'normal' generated world
        int materialNum = getStrataNum(x, y, z);
        BREAK_IF(materialNum < 0);
        BREAK_IF(materialNum >= materials.length);
        auto material = materials[materialNum];

        auto tileType = getBasicTileType(material.name);
        return Tile(tileType, flags);


    }
    TileType getBasicTileType(string _group) { 
        randomNumber++;

        auto group = tileTypeManager.getGroup(_group);
        int idx = randomNumber % cast(int)group.length;
        return group[idx];
    }

    long worldRadius = WorldSize;
    long worldRadiusSquare = (cast(long)WorldSize) ^^2;
    bool isInsideWorld(TilePos pos) {
        if(pos.value.x < 0 || pos.value.x >= WorldSize ||
           pos.value.y < 0 || pos.value.y >= WorldSize) {
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
        pos.value.x = clamp(pos.value.x, 0, WorldSize-SampleIntervall);
        pos.value.y = clamp(pos.value.y, 0, WorldSize-SampleIntervall);
        auto height = heightMaps.getHeight!false(pos);
        auto soil = heightMaps.getSoil!false(pos);
        return cast(int)ceil(height + soil);
    }

}






module worldgen.newgen;

import std.algorithm;
import std.c.process;
import std.conv;
import std.exception;
import std.math;
import std.md5;
import std.random;
import std.stdio;
import std.typecons;


import graphics.texture;
import graphics.debugging;
import light;
import pos;
import statistics;
import tiletypemanager;
import util.math;
import util.rangefromto;
import util.util;
import world.world;

import worldgen.maps;

import random.valuemap;
import random.random;
import random.randsource;
import random.gradientnoise;


enum ptPerLayer = 400;


/*

layer5: 256 mil

layer4: 64 mil

layer3: 16 mil

layer2: 4 mil

layer1: 10km², 1mil

*/

alias ValueMap2D!(double, false) ValueMap;



//alias double[ptPerLayer][ptPerLayer] Map;

class Feature {



}

final class Map {
    ValueMap heightMap;
    ValueMap randomField;
    Feature[] features;
    int level;
    vec2i mapNum;
    int randomSeed;

    this(int _level, vec2i _mapNum, int _randomSeed) {
        level = _level;
        mapNum = _mapNum;
        randomSeed = _randomSeed;
        heightMap = new ValueMap(ptPerLayer, ptPerLayer);
        randomField = new ValueMap;

        randomField.fill(new RandSourceUniform(randomSeed), ptPerLayer, ptPerLayer);
    }
    void setHeight(int x, int y, double value) {
        heightMap.set(x,y, value);
    }
    double getHeight(int x, int y) {
        return heightMap.get(x,y);
    }

    void addRandomHeight() {

        foreach(pt ; RangeFromTo(0, ptPerLayer-1, 0, ptPerLayer-1, 0, 0)) {
            auto x = pt.X;
            auto y = pt.Y;
            auto height = heightMap.get(x, y);
            height += (randomField.get(x, y) + 1.0 ) * 0.5 * ptScale[level];
            heightMap.set(x, y, height);
        }
    }


}

class LayerManager {


}




final class WorldGenerator {
    TileTypeManager sys;

    LayerManager layerManager;


    void init(TileTypeManager tileTypeManager) {
        this.params = params;
        sys = tileTypeManager;
        layerManager = new LayerManager;
        layerManager.init(params);
    }

    void serialize() {
        msg("Implement serializing worldgen");
    }
    void deserialize() {
        msg("Implement deserializing worldgen");
    }
    
    
    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }
    
    void destroy() {
        destroyed = true;
    }

    Block fillBlock(Block block) {

        auto tp0 = block.blockNum.toTilePos();

        double[BlockSize.x][BlockSize.y] zs;
        foreach (xy; RangeFromTo (0, BlockSize.x-1,
                    0, BlockSize.y-1, 0, 0)) {
            auto pos = tp0;
            pos.value += xy;
            zs[xy.Y][xy.X] = 
                layerManager.getValueInterpolated(1, TileXYPos(pos));
        }

        block.hasAir = false;
        block.hasNonAir = false;

        bool homogenous = true;
        bool first = true;
        foreach (relPos; RangeFromTo (0, BlockSize.x-1,
                    0, BlockSize.y-1, 0, BlockSize.z-1)) {
            auto tp = tp0;
            tp.value += relPos;
            auto tile = getTile(tp, zs[relPos.Y][relPos.X]);
            block.tiles.tiles[relPos.X][relPos.Y][relPos.Z] = tile;

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
            Block.free(block);
            block.tiles = null;
            block.sparse = true;
        }

        return block;
    }

    Tile getTile(TilePos pos) {
        return getTile(pos,
                layerManager.getValueInterpolated(1, TileXYPos(pos)));
    }

    Tile getTile(TilePos pos, double z) {
        TileFlags flags = cast(TileFlags)(TileFlags.valid);
        if(! isInsideWorld(pos)) {
            return Tile(TileTypeAir, flags);
        }
        if(pos.value.Z > z) {
            auto tile = Tile(TileTypeAir, flags);
            tile.sunLightValue = MaxLightStrength;
            return tile;
        }
        return Tile(TileTypeAir+1, flags);
    }

    long worldRadius = mapScale[5]/2;
    long worldRadiusSquare = (cast(long)mapScale[5]/2) ^^2;
    bool isInsideWorld(TilePos pos) {
        long dist = pos.value.X ^^ 2 + pos.value.Y ^^ 2;
        long max = worldRadiusSquare;
        return dist < max;
    } 
    int maxZ(TileXYPos xypos) {
        auto z = layerManager.getValueInterpolated(1, xypos);
        return cast(int)ceil(z);
    }

    double getHeight01(TilePos t) {
        return cast(double)maxZ(TileXYPos(t)) / 500.0;
    }

    LayerManager getLayerManager() {
        return layerManager;
    }
}





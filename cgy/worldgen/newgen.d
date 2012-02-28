
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
//import worldgen.worldgen;

import random.valuemap;
import random.random;
import random.randsource;


struct WorldGenParams {
    uint randomSeed = 880128;
    uint worldDiameter = 16; //Measures diameter of world, in number of sectors.

    double worldMin = -50;
    double worldMax = 450;

    uint heightmapSamplesInWorld() const @property {
        return worldDiameter * SectorSize.x / HeightMapSampleDistance;
    }
}

enum ptPerLayer = 400;


/*

layer5: 256 mil

layer4: 64 mil

layer3: 16 mil

layer2: 4 mil

layer1: 10km², 1mil

*/

alias ValueMap2D!(double, false) ValueMap;


/* pos 0 not used */
/* pt2tile-scale*/
enum ptScale = [0, 32, 128, 512, 2048, 8192];
/* map2tile-scale*/
enum mapScale = [0, 12800, 51200, 204800, 819200, 3276800];

enum halfWorldSize = vec3i(mapScale[5]/2, mapScale[5]/2, 0);
enum halfWorldSize_xy = vec2i(mapScale[5]/2, mapScale[5]/2);

//alias double[ptPerLayer][ptPerLayer] Map;

class Feature {
}

class Map {
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

    int maxLevel = 5;

    Map layer5;
    Map[vec2i][5] layers; /*index 0 is not used, only 1-4 because thats how things are planned out */
    WorldGenParams params;

    void init(WorldGenParams _params) {
        params = _params;
        generateTopLevel();
    }

    void generateTopLevel() {
        layer5 = new Map(5, vec2i(0,0), params.randomSeed);

        layer5.heightMap.fill(layer5.randomField, ptPerLayer, ptPerLayer);
        foreach(ref val; layer5.heightMap.randMap) {
            val = (val+1.0)*0.5 * 500;
        }

        //map.fillwithstuffandbecoolanddoneyeah();
    }

    int hash(int level, vec2i mapNum, Map parentMap) {
        vec2i local = posModV(mapNum, ptPerLayer);


        ubyte[16] digest;
        MD5_CTX context;
        context.start();
        context.update([level]);
        context.update([local]);
        context.update([parentMap.randomField.get(local.X, local.Y)]);
        context.finish(digest);
        int* ptr = cast(int*)digest.ptr;
        return ptr[0] ^ ptr[1] ^ ptr[2] ^ ptr[3];
    }

    Map getMap(int level, vec2i mapNum) {
        if(level == 5) return layer5;
        auto layer = layers[level];
        if(mapNum in layer) {
            return layer[mapNum];
        }
        writeln("Generating ", mapNum, " on level ", level);

        //auto map = getMap(level+1, negDivV(num, 4));

        auto parentMapNum = negDivV(mapNum, 4);
        auto parentMap = getMap(level+1, parentMapNum);
        auto mapSeed = hash(level, mapNum, parentMap);
        auto map = new Map(level, mapNum, mapSeed);

        /* Start by filling in the base from the previous map */


        //The index where the current map begins, in the parents pt-grid
        auto parentHeight = parentMap.heightMap;
        auto local = posModV(mapNum, 4)*100;
        double v00, v01, v10, v11;
        double deltaX = 0.0;
        double deltaY = 0.0;

        double get(int x, int y) {
            if(x < 0 || x >= 400 || y < 0 || y >= 400) {
                auto localX = posMod(x, 400);
                auto localY = posMod(y, 400);
                auto neighborParentNum = parentMapNum + vec2i(x/400, y/400);
                auto parentMap = getMap(level+1, neighborParentNum);
                return parentMap.getHeight(localX, localY);
            } else {
                return parentHeight.get(x, y);
            }
        }

        int parentY = local.Y;
        int parentX;
        foreach(y ; 0 .. ptPerLayer) {
            parentX = local.X;
            v00 = get(parentX, parentY);
            v01 = get(parentX, parentY+1); //Will crash, eventually, and then we fix something.
            v10 = get(parentX+1, parentY);
            v11 = get(parentX+1, parentY+1);
            deltaX = 0.0;
            foreach(x ; 0 .. ptPerLayer) {
                auto v_0 = lerp(v00, v10, deltaX);
                auto v_1 = lerp(v01, v11, deltaX);
                auto v = lerp(v_0, v_1, deltaY);
                map.setHeight(x, y, v);

                deltaX += 0.25;
                if( (x & 3) == 3) {
                    deltaX = 0.0;
                    parentX +=1;
                    v00 = v10;
                    v01 = v11;
                    v10 = get(parentX+1, parentY);
                    v11 = get(parentX+1, parentY+1);
                }
            }
            deltaY += 0.25;
            if( (y & 3) == 3) {
                deltaY = 0.0;
                parentY += 1;
            }
        }

        /* Add 'our own' randomness */

        map.addRandomHeight();

        /* Process the map, etc */

        /* Add river-objects, cave-objects, etc */

        /* postprocess the map */

        /* Done! Add it to our known maps =) */

        layers[level][mapNum] = map;
        return map;
    }

    int cnt = 0;
    double getValueInterpolated(int level, TileXYPos tilePos) {
        //mixin(Time!("writeln(usecs, cnt);"));
        //cnt += 1;

        auto ptNum = negDivV(tilePos.value, ptScale[level]);
        
        //Tiles from 'base' of area to pt of interes
        auto ptScale = ptScale[level];
        int dx = tilePos.value.X - ptNum.X*ptScale;
        int dy = tilePos.value.Y - ptNum.Y*ptScale;

        double dtx = cast(double)dx / cast(double)ptScale;
        double dty = cast(double)dy / cast(double)ptScale;

        auto v00 = getValueRaw(level, ptNum*ptScale);
        auto v01 = getValueRaw(level, (ptNum+vec2i(0,1))*ptScale);
        auto v10 = getValueRaw(level, (ptNum+vec2i(1,0))*ptScale);
        auto v11 = getValueRaw(level, (ptNum+vec2i(1,1))*ptScale);

        auto v0 = lerp(v00, v01, dty);
        auto v1 = lerp(v10, v11, dty);

        auto v = lerp(v0, v1, dtx);

        return v;

        /* Figure out an interpolation-scheme */
        /* Use values from getValueRaw and interpolate them */
    }

    double getValueRaw(int level, vec2i tilePos) {
        auto mapNum = negDivV(tilePos, mapScale[level]);
        auto map = getMap(level, mapNum);
        auto ptNum = posModV(negDivV(tilePos, ptScale[level]), ptPerLayer);
        return map.getHeight(ptNum.X, ptNum.Y);
    }

}




final class WorldGenerator {
    TileTypeManager sys;
    WorldGenParams params;

    LayerManager layerManager;


    void init(WorldGenParams params, TileTypeManager tileTypeManager) {
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
}





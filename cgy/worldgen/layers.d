module worldgen.layers;

import std.conv;
import std.exception;



import feature.feature;
import json;
import util.pos;
import random.random;
import random.randsource;
import random.valuemap;
import random.xinterpolate4;
import statistics;

import util.filesystem;
import util.math;
import util.rangefromto;
import util.util;

import worldgen.maps;

final class LayerMap {
    WorldMap worldMap;
    LayerMap parentMap;
    ValueMap2Dd heightMap;
    ValueMap2Dd randomField;
    Feature[] features;
    int level;
    vec2i parentMapNum;
    vec2i mapNum;
    int randomSeed;

    this(WorldMap _worldMap, LayerMap parent, vec2i _mapNum, int _level, int _randomSeed) {
        worldMap = _worldMap;
        parentMap = parent;
        level = _level;
        mapNum = _mapNum;
        parentMapNum = negDivV(mapNum, 4);
        randomSeed = _randomSeed;
        randomField = new ValueMap2Dd;
        randomField.fill(new RandSourceUniform(randomSeed), ptPerLayer, ptPerLayer);
    }

    void setTopLayer(ValueMap2Dd height) {
        heightMap = height;
    }

    void generate() {
        heightMap = new ValueMap2Dd(ptPerLayer, ptPerLayer);
        interpolateParent();
        featureAffection();
    }

    void interpolateParent() {
        mixin(MeasureTime!"Layer gen:");

        auto parentHeight = parentMap.heightMap;
        auto local = posModV(mapNum, 4)*100;

        auto get(int x, int y) {
            return parentMap.getHeight(x, y);
        }
        auto set(int x, int y, double v) {
            return setHeight(x, y, v);
        }

        upsampleX4!(BSpline, get, set)(local, Dim);
    }

    auto getFeatures() {
        return features;
    }

    void featureAffection() {
        if(parentMap !is null) {
            enforce(features.length == 0, "Somehow, when featureAffection was called, a layer already had featuers :S");
            features = parentMap.getFeatures();
        }
        foreach(feature ; features) {
            feature.affectHeightmap(this, level);
        }
    }

    void setHeight(int x, int y, double value) {
        /*
        if(x < 0 || x >= 400 || y < 0 || y >= 400) {
            auto localX = posMod(x, 400);
            auto localY = posMod(y, 400);
            auto neighborParentNum = parentMapNum +  negDivV(vec2i(x, y), 400);
            auto parentMap = worldMap.getMap(level+1, neighborParentNum);
            return parentMap.setHeight(localX, localY, value);
        }
        */
        heightMap.set(x,y, value);
    }
    double getHeight(int x, int y) {
        if(x < 0 || x >= 400 || y < 0 || y >= 400) {
            auto localX = posMod(x, 400);
            auto localY = posMod(y, 400);
            auto neighborNum = mapNum +  negDivV(vec2i(x, y), 400);
            auto siblingMap = worldMap.getMap(level, neighborNum);
            return siblingMap.getHeight(localX, localY);
        }
        return heightMap.get(x,y);
    }

    void addFeature(Feature feature) {
        // ... ignore tp! :D
        feature.init(this);
        features ~= feature;
        feature.affectHeightmap(this, level);
    }

    
    Value saveFeatures() {
        bool[Feature] feats;
        foreach(feature ; features) {
            feats[feature] = true;
        }
        if(parentMap !is null) {
            foreach(feature ; parentMap.getFeatures()) {
                feats.remove(feature);
            }
        }
        Value[] values;
        foreach(feature, _true ; feats) {
            values ~= feature.save();
        }
        return Value(values);
    }

    void loadFeatures(string path) {        
        auto root = loadJSON(path);
        foreach(idx, value ; root.asArray()) {
            auto feature = Feature.create(value);
            addFeature(feature);
        }
    }

}

mixin template Layers() {

    LayerMap[vec2i][4] layers; /*index 0 is not used, only 1-3 because thats how things are planned. And the fifth layer is not stored in that. */
    LayerMap layer4;

    ValueMap mipLevel1;
    ValueMap mipLevel2;

    int layerSeed;

    void layersInit() {
        layer4 = new LayerMap(this, null, vec2i(0), 4, layerSeed);
        layer4.setTopLayer(heightMap);
    }

    //These features are generated and immediately affect the heightmap of the world.
    void generateTopLayerFeatures() {
        //msg("do we actually need generateMipMaps(); for anything?");
        //Yep now we do. For heightsheets.
        //Are generated on request.

        //Add cone mountains at least 10 km apart.
        TileXYPos[] soFar;
        int limit = 10_000;
        foreach(asdasd ; 0 .. 100) {
            TileXYPos pt;
            while(true) {
                pt = getRandomPointOnLand();
                auto yes = true;
                foreach(tp ; soFar) {
                    auto diff = pt.value - tp.value;
                    auto distance = max(abs(diff.X), abs(diff.Y));
                    if(distance < limit) {
                        msg(distance);
                        yes = false;
                    }
                }
                if(yes) {
                    break;
                } else {
                    //addFeature(pt, new ConeMountainFeature(pt, cast(int)worldMax));
                    limit -= 1;
                }
            }
            soFar ~= pt;

            auto cone = new ConeMountainFeature(pt, cast(int)worldMax);
            addFeature(4, vec2i(0), cone);
        }
    }

    string featuresPath(string hash = null) const @property{
        return worldPath ~ "/features";
    }

    void saveAllFeatures() {
        mkdir(featuresPath);
        auto value = layer4.saveFeatures();
        value.saveJSON(featuresPath ~ "/features.json", false);
        foreach(layer ; layers[1..$]) {
            foreach(layerMap ; layer) {
                auto path = text(featuresPath, "/", layerMap.level, "/", layerMap.mapNum.X, ",", layerMap.mapNum.Y);
                mkdir(path);
                value = layerMap.saveFeatures();
                value.saveJSON(path ~ "/features.json", false);
            }
        }
    }


    void loadFeatures(int level, vec2i mapNum) {
        auto path = text(featuresPath, "/", level, "/", mapNum.X, ",", mapNum.Y, "/features.json");
        auto layer = getMap(level, mapNum);
        layer.loadFeatures(path);
    }

    void loadAllFeatures() {
        layer4.loadFeatures(featuresPath ~ "/features.json");
        foreach(level, layer ; layers[1..$]) {
            auto levelPath = text(featuresPath, "/", level);
            if(!exists(levelPath)) continue;
            foreach(item ; dir(levelPath)) {
                auto parts = item.split(",");
                auto mapNum = vec2i(to!int(parts[0]), to!int(parts[1]));
                loadFeatures(level, mapNum);
            }
        }

    }

    void generateMipMaps() {
        mipLevel1 = new ValueMap(100, 100);
        mipLevel2 = new ValueMap(25, 25);

        foreach(Y ; 0 .. ptPerLayer/4) {
            foreach(X ; 0 .. ptPerLayer/4) {
                double heightSum;
                foreach(dY ; 0 .. 4) {
                    int y = Y * 4 + dY;
                    foreach(dX ; 0 .. 4) {
                        int x = X * 4 + dX;
                        auto height = layer4.getHeight(x, y);
                        heightSum += height;
                    }
                }
                mipLevel1.set(X, Y, heightSum / 16.0);
            }
        }
        foreach(Y ; 0 .. ptPerLayer/16) {
            foreach(X ; 0 .. ptPerLayer/16) {
                double heightSum;
                foreach(dY ; 0 .. 4) {
                    int y = Y * 4 + dY;
                    foreach(dX ; 0 .. 4) {
                        int x = X * 4 + dX;
                        auto height = mipLevel1.get(x, y);
                        heightSum += height;
                    }
                }
                mipLevel2.set(X, Y, heightSum / 16.0);
            }
        }

    }

    void addFeature(int level, vec2i mapNum, Feature feature) {
        if(level == 4) {
            layer4.addFeature(feature);
            return;
        }
        enforce(hasMap(level, mapNum), "Tried to add a feature to a LayerMap we dont yet have");
        auto map = getMap(level, mapNum);
        map.addFeature(feature);
    }

    int hash(int level, vec2i mapNum, LayerMap parentMap) {
        vec2i local = posModV(mapNum, ptPerLayer);


        ubyte[16] digest;
        MD5_CTX context;
        context.start();
        context.update([level]);
        context.update([local]);
        //context.update([parentMap.randomField.get(local.X, local.Y)]);
        context.finish(digest);
        int* ptr = cast(int*)digest.ptr;
        return ptr[0] ^ ptr[1] ^ ptr[2] ^ ptr[3];
    }

    int hashShit(T...)(T t) {
        ubyte[16] digest;
        MD5_CTX context;
        context.start();
        foreach(item ; t) {
            
            context.update((&item)[0..1]);
            //context.update([parentMap.randomField.get(local.X, local.Y)]);
        }
        context.finish(digest);
        int* ptr = cast(int*)digest.ptr;
        return ptr[0] ^ ptr[1] ^ ptr[2] ^ ptr[3];
    }

    bool hasMap(int level, vec2i mapNum) {
        if(level == 4) return true;
        if(level == 0) return false;
        auto layer = layers[level];
        return (mapNum in layer) !is null;
    }

    bool loadMap(int level, vec2i mapNum) {
        auto path = text(featuresPath, "/", level, "/", mapNum.X, ",", mapNum.Y, "/");
        if(!exists(path)) return false;

        auto parentMapNum = negDivV(mapNum, 4);
        auto parentMap = getMap(level+1, parentMapNum);
        auto mapSeed = hash(level, mapNum, parentMap);
        auto map = new LayerMap(this, parentMap, mapNum, level, mapSeed);
        map.loadFeatures(path);
        layers[level][mapNum] = map;
        return true;
    }

    //This is a hack for now. Add proper synchronization when rewriting and refactoring.
    // The problem is that two tasks may want to get the same map at aproximately the same time.
    // Since it is a relatively long process to create a map at times,  multiple threads may start
    // doing so. We don't want that.
    bool generating[4][vec2i];
    LayerMap getMap(int level, vec2i mapNum) {
        BREAK_IF(level > 4);
        if(level == 4) {
            return layer4;
        }
        auto layer = layers[level];
        if(mapNum in layer) {
            return layer[mapNum];
        }
        
        if(mapNum in generating[level]) {
            core.thread.Thread.sleep(dur!"msecs"(15));
            return getMap(level, mapNum);
        }
        
        generating[level][mapNum] = true;
        if(loadMap(level, mapNum)) {
            generating[level].remove(mapNum);
            return layers[level][mapNum];
        }


        msg("Generating ", mapNum, " on level ", level);

        //auto map = getMap(level+1, negDivV(num, 4));

        auto parentMapNum = negDivV(mapNum, 4);
        auto parentMap = getMap(level+1, parentMapNum);
        auto mapSeed = hash(level, mapNum, parentMap);
        auto map = new LayerMap(this, parentMap, mapNum, level, mapSeed);
        map.generate();

        layers[level][mapNum] = map;

        if(level == 1) {
            populateLevel1(map);
        }
        generating[level].remove(mapNum);
        return map;
    }
    auto getMap(TileXYPos tileXYPos, int level) {
        auto mapNum = negDivV(tileXYPos.value, mapScale[level]);
        auto map = getMap(level, mapNum);
        return map;
    }

    void populateLevel1(LayerMap map) {
        auto mapNum = map.mapNum;
        int cnt = 0;

        //Place a tree about every 8'th meter
        //A growth density value is obtained from the area type.
        // A hash of some properties is compared to this value.
        // If the hash is lower than the density value, a tree is placed.
        //  Should work as long as the hash is random enough.
        immutable treeDistance = 8;
        foreach(x, y ; Range2D(vec2i(0), vec2i(mapScale[1]) / treeDistance)) {

            //Determine the biome. Determine forrest density. Determine what tree type.
            auto area = getArea( TileXYPos(vec2i(x + treeDistance / 2, y + treeDistance / 2)));
            if(area.isSea) continue;
            auto climate = area.climateType;
            auto density = climate;
            int hash = abs(hashShit(mapNum.X, mapNum.Y, area.areaId, x, y));
            int lower = hash % 0x0F;
            //msg(lower, " ", density);
            if(lower < density) {
                cnt++;
                //Add tree.
                //Use hash to place
                int high = (hash >> 16) & 0xFFFF;
                int low = hash & 0xFFFF;
                auto pos =  (vec2i(high, low).convert!double * (cast(double)treeDistance / 0xFFFF)).convert!int + mapNum * mapScale[1] + vec2i(x, y)*treeDistance;
                //lawl

                //Get tree-type-group from climate, use hash to determine what. use some upper bits.
                addFeature(1, mapNum, new TreeFeature(TileXYPos(pos)));
            }
        }
        msg("Added ", cnt, " trees of ", mapScale[1]^^2 / 8^^2, " possible");
    }

    double getValueInterpolated(int level, TileXYPos tilePos) {
        //mixin(Time!("msg(usecs, cnt);"));
        //cnt += 1;

        auto ptScale = ptScale[level];
        auto ptNum = negDivV(tilePos.value, ptScale);

        //Tiles from 'base' of area to pt of interest
        int dx = tilePos.value.X - ptNum.X*ptScale;
        int dy = tilePos.value.Y - ptNum.Y*ptScale;

        double dtx = cast(double)dx / cast(double)ptScale;
        double dty = cast(double)dy / cast(double)ptScale;

        //Replace these calls. Lots of redundant operations.
        auto v00 = getValueRaw(level, (ptNum+vec2i(-1,-1))*ptScale);
        auto v01 = getValueRaw(level, (ptNum+vec2i(-1, 0))*ptScale);
        auto v02 = getValueRaw(level, (ptNum+vec2i(-1, 1))*ptScale);
        auto v03 = getValueRaw(level, (ptNum+vec2i(-1, 2))*ptScale);
        auto v10 = getValueRaw(level, (ptNum+vec2i( 0,-1))*ptScale);
        auto v11 = getValueRaw(level, (ptNum+vec2i( 0, 0))*ptScale);
        auto v12 = getValueRaw(level, (ptNum+vec2i( 0, 1))*ptScale);
        auto v13 = getValueRaw(level, (ptNum+vec2i( 0, 2))*ptScale);
        auto v20 = getValueRaw(level, (ptNum+vec2i( 1,-1))*ptScale);
        auto v21 = getValueRaw(level, (ptNum+vec2i( 1, 0))*ptScale);
        auto v22 = getValueRaw(level, (ptNum+vec2i( 1, 1))*ptScale);
        auto v23 = getValueRaw(level, (ptNum+vec2i( 1, 2))*ptScale);
        auto v30 = getValueRaw(level, (ptNum+vec2i( 2,-1))*ptScale);
        auto v31 = getValueRaw(level, (ptNum+vec2i( 2, 0))*ptScale);
        auto v32 = getValueRaw(level, (ptNum+vec2i( 2, 1))*ptScale);
        auto v33 = getValueRaw(level, (ptNum+vec2i( 2, 2))*ptScale);

        auto v0 = BSpline(v00, v01, v02, v03, dty);
        auto v1 = BSpline(v10, v11, v12, v13, dty);
        auto v2 = BSpline(v20, v21, v22, v23, dty);
        auto v3 = BSpline(v30, v31, v32, v33, dty);

        return BSpline(v0, v1, v2, v3, dtx);
    }

    double getValueRaw(int level, vec2i tilePos) {
        auto ptNum = posModV(negDivV(tilePos, ptScale[level]), ptPerLayer);
        if(level == 5 || level == 6) {
            if(mipLevel1 is null)  {
                generateMipMaps();
            }
            auto map = (level == 5) ? mipLevel1 : mipLevel2;
            ptNum = (level == 5) ? ptNum / 4 : ptNum / 16;
            //ptNum = clampV(ptNum, vec2i(0), vec2i(Dim-1));
            return map.get(ptNum.X, ptNum.Y);
        }
        auto mapNum = negDivV(tilePos, mapScale[level]);
        auto map = getMap(level, mapNum);
        return map.getHeight(ptNum.X, ptNum.Y);
    }



}

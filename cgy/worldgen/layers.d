module worldgen.layers;

import std.conv;

import random.valuemap;

import worldgen.maps;

import util.util;

class Feature {
}


final class LayerMap {
    ValueMap2Dd heightMap;
    ValueMap2Dd randomField;
    Feature[] features;
    int level;
    vec2i mapNum;
    int randomSeed;

    this(int _level, vec2i _mapNum, int _randomSeed) {
        level = _level;
        mapNum = _mapNum;
        randomSeed = _randomSeed;
        heightMap = new ValueMap2Dd(ptPerLayer, ptPerLayer);
        //randomField = new ValueMap2Dd;

        //randomField.fill(new RandSourceUniform(randomSeed), ptPerLayer, ptPerLayer);
    }

    this(ValueMap2Dd topHeightmap) {
        level = 5;
        mapNum.set(0, 0);

        heightMap = topHeightmap;
    }
    void setHeight(int x, int y, double value) {
        heightMap.set(x,y, value);
    }
    double getHeight(int x, int y) {
        return heightMap.get(x,y);
    }

}

template shift(string q, string w, string e, string r, string t) {
    enum shift = text(q, "=", w, "; ", w, "=", e, "; ", e, "=", r, "; ", r, "=", t, ";");
}


mixin template Layers() {

    LayerMap[vec2i][5] layers; /*index 0 is not used, only 1-4 because thats how things are planned. And the fifth layer is not stored in that. */
    LayerMap layer5;

    ValueMap mipLevel1;
    ValueMap mipLevel2;

    void layersInit() {
        layer5 = new LayerMap(heightMap);
        //enforce(0, "Implement this here layers thing");
    }

    void generateTopLayer() {
        msg("do we actually need generateMipMaps(); for anything?");

        //When do we scan the toplayer to identify mountains, peaks etc?
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
                        auto height = layer5.getHeight(x, y);
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

    bool hasMap(int level, vec2i mapNum) {
        if(level == 5) return true;
        if(level == 0) return false;
        auto layer = layers[level];
        return (mapNum in layer) !is null;
    }


    LayerMap getMap(int level, vec2i mapNum) {
        if(level == 5) {
            return layer5;
        }
        auto layer = layers[level];
        if(mapNum in layer) {
            return layer[mapNum];
        }
        writeln("Generating ", mapNum, " on level ", level);

        //auto map = getMap(level+1, negDivV(num, 4));

        auto parentMapNum = negDivV(mapNum, 4);
        auto parentMap = getMap(level+1, parentMapNum);
        auto mapSeed = hash(level, mapNum, parentMap);
        auto map = new LayerMap(level, mapNum, mapSeed);

        /* Start by filling in the base from the previous map */

        //The index where the current map begins, in the parents pt-grid

        /*
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
        //*/

        //*
        {
            mixin(MeasureTime!"Layer gen:");

        auto parentHeight = parentMap.heightMap;
        auto local = posModV(mapNum, 4)*100;

        double get(int x, int y) {
            if(x < 0 || x >= 400 || y < 0 || y >= 400) {
                auto localX = posMod(x, 400);
                auto localY = posMod(y, 400);
                auto neighborParentNum = parentMapNum +  negDivV(vec2i(x, y), 400);
                auto parentMap = getMap(level+1, neighborParentNum);
                return parentMap.getHeight(localX, localY);
            } else {
                return parentHeight.get(x, y);
            }
        }

        double v00, v01, v02, v03, v10, v11, v12, v13, v20, v21, v22, v23, v30, v31, v32, v33;
        double i0, i1, i2, i3;
        double deltaX = 0.0;
        double deltaY = 0.0;
        int parentY = local.Y;
        int parentX;
        foreach(y ; 0 .. ptPerLayer) {
            parentX = local.X;

            v00 = get(parentX-1, parentY-1);
            v01 = get(parentX-1, parentY+0);
            v02 = get(parentX-1, parentY+1);
            v03 = get(parentX-1, parentY+2);
            v10 = get(parentX+0, parentY-1);
            v11 = get(parentX+0, parentY+0);
            v12 = get(parentX+0, parentY+1);
            v13 = get(parentX+0, parentY+2);
            v20 = get(parentX+1, parentY-1);
            v21 = get(parentX+1, parentY+0);
            v22 = get(parentX+1, parentY+1);
            v23 = get(parentX+1, parentY+2);
            v30 = get(parentX+2, parentY-1);
            v31 = get(parentX+2, parentY+0);
            v32 = get(parentX+2, parentY+1);
            v33 = get(parentX+2, parentY+2);
            i0 = CubicInter(v00, v01, v02, v03, deltaY);
            i1 = CubicInter(v10, v11, v12, v13, deltaY);
            i2 = CubicInter(v20, v21, v22, v23, deltaY);
            i3 = CubicInter(v30, v31, v32, v33, deltaY);

            deltaX = 0.0;
            foreach(x ; 0 .. ptPerLayer) {
                auto v = CubicInter(i0, i1, i2, i3, deltaX);
                map.setHeight(x, y, v);

                deltaX += 0.25;
                if( (x & 3) == 3) {
                    deltaX = 0.0;
                    parentX +=1;
                    mixin(shift!("v00", "v10", "v20", "v30", "get(parentX+2, parentY-1)"));
                    mixin(shift!("v01", "v11", "v21", "v31", "get(parentX+2, parentY+0)"));
                    mixin(shift!("v02", "v12", "v22", "v32", "get(parentX+2, parentY+1)"));
                    mixin(shift!("v03", "v13", "v23", "v33", "get(parentX+2, parentY+2)"));
                    mixin(shift!("i0", "i1", "i2", "i3", "CubicInter(v30, v31, v32, v33, deltaY)"));

                }
            }
            deltaY += 0.25;
            if( (y & 3) == 3) {
                deltaY = 0.0;
                parentY += 1;
            }
        }

        }
        //*/

        /*

        {
            mixin(MeasureTime!("To make layer:"));
            auto layerSize = vec2d(mapScale[level]);
            auto layerRect = Rectd(layerSize * mapNum.convert!double, layerSize);

            auto interpolated = new CubicInterpolation(parentMap.heightMap);

            auto local = (posModV(mapNum, 4)*100).convert!double;
            auto parentMapArea = Rectd(local, vec2d(100));
            auto scaled = MapRectToSize(interpolated, parentMapArea, vec2d(400));
            //The big problem with this is that we can't get data from different parent areas :P

            map.heightMap.fill(scaled, 400, 400);
        }
        //*/

        /* Add 'our own' randomness */

        /* Process the map, etc */

        /* Add river-objects, cave-objects, etc */

        /* postprocess the map */

        /* Done! Add it to our known maps =) */

        layers[level][mapNum] = map;
        return map;
    }

    void initLayer4(LayerMap layer) {

        /*
        // How would and _area_ apply or change things, anyway?
        // It's more likely they add a feature or something which modifies the height,
        // but it's not like a tundra, jungle or a desert affects the height of the world
        // by being a desert...
        //
        // So maybe use this as a point to add features.
        //
        // Or add different kinds of noise depending on what kind of terrain there is?
        // IN THAT CASE USE A DISPLACEMENT FIELD AS WELL?????
        //
        foreach(area ; getLayerAreas(4, layer.mapNum)) {
            area.applyHeight(layer);
        }
        */

        /*
        foreach(feature ; getLevelFeatures(4, layer.mapNum)) {
            feature.applyHeight(layer);
        }
        */
        enforce(0, "herp derp");
    }


    double getValueInterpolated(int level, TileXYPos tilePos) {
        //mixin(Time!("writeln(usecs, cnt);"));
        //cnt += 1;

        auto ptScale = ptScale[level];
        auto ptNum = negDivV(tilePos.value, ptScale);

        //Tiles from 'base' of area to pt of interes
        int dx = tilePos.value.X - ptNum.X*ptScale;
        int dy = tilePos.value.Y - ptNum.Y*ptScale;

        double dtx = cast(double)dx / cast(double)ptScale;
        double dty = cast(double)dy / cast(double)ptScale;

        //Replace these calls. Lots of redundant operations.
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
        auto ptNum = posModV(negDivV(tilePos, ptScale[level]), ptPerLayer);
        if(level == 6 || level == 7) {
            auto map = (level == 6) ? mipLevel1 : mipLevel2;
            return map.get(ptNum.X, ptNum.Y);
        }
        auto mapNum = negDivV(tilePos, mapScale[level]);
        auto map = getMap(level, mapNum);
        return map.getHeight(ptNum.X, ptNum.Y);
    }

    /*
    vec3f getBiomeColor(vec2i tp) {
        return vec3f(0.7f, 0.7f, 0.7f);
    }
    */


}

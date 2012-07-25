module worldgen.layers;




mixin template Layers() {

    Map[vec2i][5] layers; /*index 0 is not used, only 1-4 because thats how things are planned. And the fifth layer is not stored in that. */
    Map layer5;
    ValueMap mipLevel1;
    ValueMap mipLevel2;

    void init() {
        generateTopLevel();
    }

    void generateTopLevel() {
        layer5 = new Map(5, vec2i(0,0), params.randomSeed);

        layer5.heightMap.fill(layer5.randomField, ptPerLayer, ptPerLayer);
        foreach(ref val; layer5.heightMap.randMap) {
            val = (val+1.0)*0.5 * 15000;
        }

        //map.fillwithstuffandbecoolanddoneyeah();

        generateMipMaps();
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

    bool hasMap(int level, vec2i mapNum) {
        if(level == 5) return true;
        if(level == 0) return false;
        auto layer = layers[level];
        return (mapNum in layer) !is null;
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

    vec3f getBiomeColor(vec2i tp) {
        return vec3f(0.7f, 0.7f, 0.7f);
    }


}

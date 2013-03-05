
module worldstate.ambient;


mixin template LightStorageMethods() {

    import std.container : BinaryHeap, heapify;
    import util.array : Array;
    import alloc : temp_alloc_malloc, temp_alloc_free, AA;

    struct LightPropagationData {
        TilePos tilePos;
        byte strength;
    }
    alias util.array.Array!LightPropagationData LPDArray;
    alias BinaryHeap!(LPDArray, "a.strength < b.strength") LightHeap;
    alias AA!(BlockNum, bool, temp_alloc_malloc, temp_alloc_free) BlockNumSet;

    LightHeap lightSources;
    LightHeap sunLightSources;
    LightHeap sunUnLight;
    LightHeap unspread;

    unittest {
        alias util.array.ArrayClass!int ASD;
        alias BinaryHeap!(ASD, "a < b") DSA;
        auto arr = new ASD();
        auto heap = DSA();
        msg(&arr);
        msg(&arr.storage);
        heap.assume(arr);
        heap.insert(1);
        heap.insert(2);
        heap.insert(3);
        msg(heap.length);
        msg(arr.length);

        arr.length = 0;
        msg(heap.length);
        msg(arr.length);
        heap.assume(arr);
        msg(heap.length);
        msg(arr.length);
        heap.insert(1);
        heap.insert(2);
        heap.insert(3);
        heap.insert(4);
        msg(heap.length);
        msg(arr.length);
    }


    private void unspreadLights(bool sunLight, ref LightHeap lightSources, LightHeap toUnlight, ref BlockNumSet modifiedBlocks) {

        while(!toUnlight.empty()) {
            auto data = toUnlight.front();
            toUnlight.removeFront();

            byte oldLightValue = data.strength;
            auto tilePos = data.tilePos;
            modifiedBlocks[tilePos.getBlockNum()] = true;
            setTileLightVal(tilePos, 0, sunLight); //Visited; Now move along, nothing to see here.

            foreach(newTilePos ; neighbors(data.tilePos)) {
                modifiedBlocks[newTilePos.getBlockNum()] = true;
                auto tile = getTile(newTilePos);
                if (!tile.isAir) continue; //Dont affect solid tiles, in fact dont care about them at all
                byte neighborLightValue = tile.getLight(sunLight);
                if( neighborLightValue <= 0) continue; //Dont continue to unflood where there is no light. We might have come here earlier, from anotehr direction
                if(neighborLightValue < oldLightValue) { //If the value is less than where we came from (and > 0), mark it and add to visit.
                    //Tile has lower light value; Add to unspread-queue
                    setTileLightVal(newTilePos, 0, sunLight);
                    toUnlight.insert(LightPropagationData(newTilePos, neighborLightValue));

                //If we encountered a value higher than our own, add it so we can flood back from it.
                // Used to be >= but since we now support batched changes, two tiles next to each other might
                //  have the same value, and BOTH shall be visited, so don't prematurely mark it as flood-back-from!
                //   Although.. how does one handle cases like 5  4  3 [3] [4] [5] ...
                //    It will not unflood into the 3. But it will not flood back either. Remarkably annoying!
                } else if(neighborLightValue >= oldLightValue) {
                    //Floodfill back in again
                    lightSources.insert(LightPropagationData(newTilePos, neighborLightValue));
                }
            }
        }
    }

    private void spreadLights(bool sunLight, LightHeap lightSources, ref BlockNumSet modifiedBlocks) {
        while(!lightSources.empty){
            auto source = lightSources.front;
            lightSources.removeFront();
            auto lightStrength = source.strength;
            auto tilePos = source.tilePos;
            modifiedBlocks[tilePos.getBlockNum()] = true;
            setTileLightVal(tilePos, lightStrength, sunLight);
            byte spreadLightStrength = cast(byte)(lightStrength-1);
            foreach(newTilePos ; neighbors(source.tilePos)) {
                modifiedBlocks[newTilePos.getBlockNum()] = true;
                Tile tile = getTile(newTilePos);
                if( !tile.isAir) continue;
                byte neighborLightValue = tile.getLight(sunLight);

                if(neighborLightValue > lightStrength+1) {
                    //If we encounter a neighbor with stronger light than that of the current light,
                    //then we need to spread the light backwards :p
                    //BREAKPOINT; //Not sure when it might happen but it might.. :)
                    //Case found, see http://luben.se/wiki/index.php?page=flooding_lulz
                    byte newLightVal = cast(byte)(neighborLightValue-1);
                    setTileLightVal(tilePos, newLightVal, sunLight);
                    lightSources.insert(LightPropagationData(tilePos, newLightVal));
                } else if(neighborLightValue < spreadLightStrength) {
                    //Else if neighbor has lower light than we want to spread, spread light! (if we can :p)
                    if(spreadLightStrength > 0) {
                        setTileLightVal(newTilePos, spreadLightStrength, sunLight);
                        lightSources.insert(LightPropagationData(newTilePos, cast(byte)spreadLightStrength));
                    }
                }
            }
        }
    }

    private void addLight(LightSource light) {
        TilePos tilePos = light.position.tilePos();
        BlockNumSet modifiedBlocks;
        modifiedBlocks.init(1024);
        scope (exit) {
            if (modifiedBlocks.size > 1024) {
                msg("modifiedBlocks too small :<");
            }
            modifiedBlocks.destroy();
        }

        auto sectorNum = tilePos.getSectorNum;
        auto sector = getSector(sectorNum);
        enforce(sector !is null, "Cant add lights to sectors that dont exist you dummy!");
        sector.addLight(light);
        
        LightHeap lights;
        lights.insert(LightPropagationData(tilePos, light.strength));
        spreadLights(false, lights, modifiedBlocks);

        notifyAllUpdateGeometry(modifiedBlocks);
    }
    void unsafeAddLight(LightSource light) {
        addLight(light);
    }
    void unsafeRemoveLight(LightSource light) {
        TilePos tilePos = light.position.tilePos();
        BlockNumSet modifiedBlocks;
        modifiedBlocks.init(1024);
        scope (exit) {
            if (modifiedBlocks.size > 1024) {
                msg("modifiedBlocks too small :<");
            }
            modifiedBlocks.destroy();
        }

        auto sectorNum = tilePos.getSectorNum;
        auto sector = getSector(sectorNum);
        enforce(sector !is null, "Cant remove lights to sectors that dont exist you dummy!");
        sector.removeLight(light);

        LightHeap lightSources;
        LightHeap toUnspread;
        toUnspread.insert(LightPropagationData(tilePos, light.strength));
        //unspreadLights(false, lightSources, toUnspread, modifiedBlocks);
        unspreadLights(false, lightSources, toUnspread, modifiedBlocks);
        spreadLights(false, lightSources, modifiedBlocks);

        notifyAllUpdateGeometry(modifiedBlocks);
    }



    //For each removed tile:
    //If we opened up for a ray of sunlight to shoot down a hole, set all the air in the hole
    // to be sunlight, and add them as light-spreading-sources.
    //Also find the brightest lit tile in the vincinity, and spread light from it if possible
    //Then for each tile we spread from, spread the light! =)
    //Then notify and update the geometry
    // Remember, removing a tile will only ever increase the spread light, not remove light!
    void removeTile(Tile[TilePos] tilePositions) {
        LightHeap lightSources;
        LightHeap sunLightSources;
        BlockNumSet modifiedBlocks;
        modifiedBlocks.init(1024);
        scope (exit) {
            if (modifiedBlocks.size > 1024) {
                msg("modifiedBlocks too small :<");
            }
            modifiedBlocks.destroy();
        }
        foreach(tilePos, newTile ; tilePositions) {
            auto tileAbove = getTile(TilePos(tilePos.value + vec3i(0, 0, 1)));
            bool belowSunlight = tileAbove.sunlight;
            //No need to unspread light; Removing a tile will never cause light to diminish

            if( belowSunlight) {
                //If below sunlight, spread sunlight downward until we find a solid object.
                //Will add light collumn to lights to spread
                int z = tilePos.value.z; 
                while(true){
                    auto iterTilePos = TilePos(vec3i(tilePos.value.x, tilePos.value.y, z));
                    auto iterTile = getTile(iterTilePos);
                    if(!iterTile.isAir) {
                        break;
                    }
                    //If we dont set this, then if we get a collumn of 3 new sunlighttiles, then
                    //when the first tile is processed, we will find that the one below isn't
                    //the same value, thus introducing a fourth iteration, which will override
                    //the second iteration, and so on.
                    modifiedBlocks[iterTilePos.getBlockNum()] = true;
                    setTileLightVal(iterTilePos, MaxLightStrength, true);
                    sunLightSources.insert(LightPropagationData(iterTilePos, MaxLightStrength));
                    z--;
                }
            }
            //Move this part of finding neighbor to separate function?
            byte max = 0;
            byte maxSun = 0;
            LightPropagationData brightest;
            LightPropagationData brightestSun;
            foreach(newPos; neighbors(tilePos)) {
                auto newTilePos = newPos;
                auto newTile = getTile(newTilePos);
                byte newStrength = newTile.lightValue;
                byte newSunStrength = newTile.sunLightValue;
                if(newStrength > max) {
                    brightest.tilePos = newTilePos;
                    brightest.strength = newStrength;
                    max = newStrength;
                }
                if(!belowSunlight && newSunStrength > maxSun) {
                    brightestSun.tilePos = newTilePos;
                    brightestSun.strength = newSunStrength;
                    maxSun = newSunStrength;
                }
            }
            if(max > 1) {
                lightSources.insert(brightest);
            }

            if(maxSun > 1) {
                sunLightSources.insert(brightestSun);
            }
        }

        spreadLights(false, lightSources, modifiedBlocks);
        spreadLights(true, sunLightSources, modifiedBlocks);

        notifyAllUpdateGeometry(modifiedBlocks);
    }

    void addTile(Tile[TilePos] tilePositions) {
        BlockNumSet modifiedBlocks;
        modifiedBlocks.init(1024);
        scope (exit) {
            if (modifiedBlocks.size > 1024) {
                msg("modifiedBlocks too small :<");
            }
            modifiedBlocks.destroy();
        }
        foreach(tilePos, oldTile; tilePositions) {
            auto oldSunLight = oldTile.getLight(true);
            auto tile = getTile(tilePos);

            sunUnLight.insert(LightPropagationData(tilePos, oldSunLight));
            setTileLightVal(tilePos, 0, true);
            if (oldTile.sunlight) {
                //If below sunlight, spread sunlight downward until we find a solid object.
                //Will add light collumn to lights to spread
                int z = tilePos.value.z-1;
                while (true) {
                    auto iterTilePos = TilePos(vec3i(
                                tilePos.value.x, tilePos.value.y, z));
                    auto iterTile = getTile(iterTilePos);
                    auto iterTileStrength = tile.getLight(true);
                    if(!iterTile.isAir || iterTileStrength == 0) {
                        break;
                    }
                    setTileLightVal(iterTilePos, 0, true); //LET HTERE BE NO ENLIGHETNMENT
                    modifiedBlocks[iterTilePos.getBlockNum()] = true; //ENTAR AN ERA OF DAKRNESS
                    sunUnLight.insert(LightPropagationData(iterTilePos, iterTileStrength));
                    z -= 1;
                }
            }
            auto oldVal = oldTile.getLight(false);
            if(oldVal) {
                unspread.insert(LightPropagationData(tilePos, oldVal));
            }
            unspreadLights(false, lightSources, unspread, modifiedBlocks);
            unspreadLights(true, sunLightSources, sunUnLight, modifiedBlocks);

            spreadLights(false, lightSources, modifiedBlocks);
            spreadLights(true, sunLightSources, modifiedBlocks);
        }

        notifyAllUpdateGeometry(modifiedBlocks);
    }

    private void notifyAllUpdateGeometry(ref BlockNumSet modifiedBlocks) {
        foreach(blockNum, trueVal; modifiedBlocks) {
            auto tilePos = blockNum.toTilePos();
            notifyUpdateGeometry(tilePos);
        }
    }

    void getLightsWithin(TilePos min, TilePos max, ref LightPropagationData[] lightSources) {
        foreach (num; RangeFromTo(min.getSectorNum().value, max.getSectorNum().value)) {
            auto sectorNum = SectorNum(num);
            auto sector = getSector(sectorNum);
            if(sector is null) continue;
            auto lights = sector.getLightsWithin(min, max);
            foreach(light ; lights) {
                auto data = LightPropagationData(light.position.tilePos, light.strength);
                lightSources ~= data;
            }
        }
    }

    LightSource[] getLightsInRadius(UnitPos pos, float radius) {
        //TODO: Make fix this to determine what sectors are interesting, in a not-retarded way.
        LightSource[] lights;
        auto Min = TilePos(pos.tilePos.value-vec3i(cast(int)radius));
        auto Max = TilePos(pos.tilePos.value+vec3i(cast(int)radius));
        float radius2 = radius*radius;
        foreach(rel; RangeFromTo (Min.getSectorNum.value, Max.getSectorNum.value)) {
            SectorNum sectorNum = SectorNum(rel);
            Sector sector = getSector(sectorNum);
            if(sector !is null) {
                foreach(light ; sector.lights) {
                    if(pos.value.getDistanceSQ(light.position.value) < radius2) {
                        lights ~= light;
                    }
                }
            }
        }
        return lights;
    }

}


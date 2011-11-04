
module world.ambient;



mixin template LightStorageMethods() {

    struct LightPropagationData {
        TilePos p;
        byte strength;
    }
    alias RedBlackTree!(LightPropagationData, q{a.p.value < b.p.value}) TileSet;

    TileSet open = null;
    TileSet current= null;
    TileSet closed = null;

    void createSets() {
        if(open is null) {
            open = new TileSet;
            current = new TileSet;
            closed = new TileSet;
        }
    }

    private void addLight(LightSource light) {
        TilePos tp = UnitPos(light.position).tilePos();

        aabbd aabb = tp.getAABB();
        aabb.scale(vec3d(0.4));
        addAABB(aabb, vec3f(0,0, 0.8));

        auto sectorNum = tp.getSectorNum;
        auto sector = getSector(sectorNum);
        enforce(sector !is null, "Cant add lights to sectors that dont exist you dummy!");
        sector.addLight(light);
        auto min = TilePos(tp.value - vec3i(MaxLightStrength,MaxLightStrength,MaxLightStrength));
        auto max = TilePos(tp.value + vec3i(MaxLightStrength,MaxLightStrength,MaxLightStrength));
        recalculateLight(min, max); //No need to update sunlight
        foreach(rel ; RangeFromTo(-1,1,-1, 1, -1, 1)) {
            notifyUpdateGeometry(TilePos(tp.value + rel*vec3i(MaxLightStrength,MaxLightStrength,MaxLightStrength)));
        }
        //recalculateLight(tp);

    }
    void unsafeAddLight(LightSource light) {
        addLight(light);
    }

    void recalculateAllLight(TilePos centre) {
        auto min = TilePos(centre.value-vec3i(MaxLightStrength, MaxLightStrength, MaxLightStrength));
        auto max = TilePos(centre.value+vec3i(MaxLightStrength, MaxLightStrength, MaxLightStrength));
        recalculateLight(min, max);
        recalculateSunLight(min, max);

        foreach(rel ; RangeFromTo(-1,1,-1, 1, -1, 1)) {
            notifyUpdateGeometry(TilePos(centre.value + rel*vec3i(MaxLightStrength,MaxLightStrength,MaxLightStrength)));
        }
    }


    void recalculateLight(TilePos min, TilePos max) {
        createSets();

        foreach(rel ; RangeFromTo (min.value, max.value)) {
            auto tp = TilePos(rel);
            //Tile tile = getTile(tp);
            //tile.lightValue = 0;
            //setTile(tp, tile); //We dont care about sending changes for this. It is calculated clientside anyway.
            setTileLightVal(tp, 0, false); //We dont care about sending changes for this. It is calculated clientside anyway.
        }
        auto lights = getAffectingLights(min, max);

        foreach(light ; lights) {
            auto startTile = TilePos(convert!int(light.position));
            open.insert(LightPropagationData(startTile, light.strength));
        }
        while (!open.empty) {
            swap(open, current);
            while (!current.empty) {
                auto d = current.removeAny();
                closed.insert(d);
                auto tilePos = d.p;
                auto tile = getTile(tilePos, false); //Dont create block
                if (tile.type != TileTypeAir) continue;
                tile.lightValue = cast(byte)((cast(byte)tile.lightValue) + (cast(byte)d.strength));
                if(within(tilePos.value, min.value, max.value)){
                    setTileLightVal(tilePos, tile.lightValue, false);
                    //setTile(tilePos, tile);
                }
                //notifyTileChange(tilePos);
                if (d.strength == 1) {
                    continue;
                }
                if(tile.type != TileTypeAir) {
                    continue;
                }
                foreach(neighbor ; neighbors(tilePos)) {
                    auto tmp = LightPropagationData(neighbor, 0);
                    if(!(tmp in closed) && !(tmp in current)){
                        open.insert(LightPropagationData(neighbor, cast(byte)(d.strength-1)));
                    }
                }
            }
        }
        open.clear();
        current.clear();
        closed.clear();

    }

    void recalculateSunLight(TilePos min, TilePos max) {
        createSets();

        foreach(rel ; RangeFromTo (min.value, max.value)) {
            auto tp = TilePos(rel);
            //Tile tile = getTile(tp);
            //tile.lightValue = 0;
            //setTile(tp, tile); //We dont care about sending changes for this. It is calculated clientside anyway.
            setTileLightVal(tp, 0, true); //We dont care about sending changes for this. It is calculated clientside anyway.
        }

        auto tiles = getSunTiles(min, max);
        foreach( tilePos ; tiles ) {
            open.insert(LightPropagationData(tilePos, MaxLightStrength));
        }
        while (!open.empty) {
            swap(open, current);
            while (!current.empty) {
                auto d = current.removeAny();
                closed.insert(d);
                auto tilePos = d.p;
                auto tile = getTile(tilePos, false); //Dont create block
                if (tile.type != TileTypeAir) continue;
                tile.lightValue = cast(byte)((cast(byte)tile.lightValue) + (cast(byte)d.strength));
                if(within(tilePos.value, min.value, max.value)){
                    setTileLightVal(tilePos, tile.lightValue, true);
                    //setTile(tilePos, tile);
                }
                //notifyTileChange(tilePos);
                if (d.strength == 1) {
                    continue;
                }
                if(tile.type != TileTypeAir) {
                    continue;
                }
                foreach(neighbor ; neighbors(tilePos)) {
                    auto tmp = LightPropagationData(neighbor, 0);
                    if(neighbor.value.Z > tilePos.value.Z && //Dont spread up unecessarily
                       neighbor.value.Z > getTopTilePos(TileXYPos(vec2i(tilePos.value.X, tilePos.value.Y))).value.Z) {
                           continue;
                       }
                    if(!(tmp in closed) && !(tmp in current)){
                        open.insert(LightPropagationData(neighbor, cast(byte)(d.strength-1)));
                    }
                }
            }
        }
        open.clear();
        current.clear();
        closed.clear();
    }

    void spreadSunLight(SectorNum sectorNum) {
        return;
        createSets();
        auto sectorTilePos = sectorNum.toTilePos();
        auto min = sectorTilePos;
        auto max = TilePos(min.value + vec3i(SectorSize.x-1, SectorSize.y-1, SectorSize.z-1));
        //TODO: Implement min/max of local heightmap to ease spreading of sunlight.
        foreach(pos ; RangeFromTo(vec3i(0), vec3i(SectorSize.x, SectorSize.y, 0))) {
            auto tileXYPos = TileXYPos(vec2i(sectorTilePos.value.X + pos.X, sectorTilePos.value.Y + pos.Y));
            auto topTilePos = getTopTilePos(tileXYPos);
            auto topZ = topTilePos.value.Z;
            if(topZ >= min.value.Z && topZ < max.value.Z) {
                open.insert(LightPropagationData(TilePos(topTilePos.value+vec3i(0,0,1)), MaxLightStrength));
            }
        }
        while (!open.empty) {
            swap(open, current);
            while (!current.empty) {
                auto d = current.removeAny();
                closed.insert(d);
                auto tilePos = d.p;
                auto tile = getTile(tilePos, false); //Dont create block
                if (tile.type != TileTypeAir) continue;
                tile.lightValue = cast(byte)((cast(byte)tile.lightValue) + (cast(byte)d.strength));
                setTileLightVal(tilePos, tile.lightValue, true);
                //notifyTileChange(tilePos);
                if (d.strength == 1) {
                    continue;
                }
                if(tile.type != TileTypeAir) {
                    continue;
                }
                foreach(neighbor ; neighbors(tilePos)) {
                    if(! within(neighbor.value, min.value, max.value)) {
                        continue;
                    }
                    if(neighbor.value.Z > tilePos.value.Z && //Dont spread up unecessarily
                       neighbor.value.Z > getTopTilePos(TileXYPos(vec2i(tilePos.value.X, tilePos.value.Y))).value.Z) {
                           continue;
                       }
                    auto tmp = LightPropagationData(neighbor, 0);
                    if(!(tmp in closed) && !(tmp in current)){
                        open.insert(LightPropagationData(neighbor, cast(byte)(d.strength-1)));
                    }
                }
            }
        }
        notifyBuildGeometry(sectorNum);
        open.clear();
        current.clear();
        closed.clear();
    }

    LightSource[] getAffectingLights(TilePos min, TilePos max) {
        //Lightstrength has max limit of MaxLightStrength, so we need only look in ±MaxLightStrength-tile vincinity.
        bool[SectorNum] sectors; //Lets make a naive implementation!!
        //TODO: Make fix this to determine what sectors are interesting, in a not-retarded way.
        LightSource[] lights;
        auto Min = TilePos(min.value-vec3i(MaxLightStrength,MaxLightStrength,MaxLightStrength));
        auto Max = TilePos(max.value+vec3i(MaxLightStrength,MaxLightStrength,MaxLightStrength));
        foreach(rel; RangeFromTo (Min.value, Max.value)) {
            TilePos tp = TilePos(rel);
            SectorNum sectorNum = tp.getSectorNum();
            if( sectorNum in sectors) {
                continue;
            }
            sectors[sectorNum] = false; //hohoho just for the kicks of it!
            Sector sector = getSector(sectorNum);
            if(sector !is null) {
                lights ~= sector.getLightsWithin(Min, Max);
            }
        }
        return lights;
    }

    TilePos[] getSunTiles(TilePos min, TilePos max) {
        TilePos[] tiles;
        min = TilePos(min.value-vec3i(MaxLightStrength,MaxLightStrength,MaxLightStrength));
        max = TilePos(max.value+vec3i(MaxLightStrength,MaxLightStrength,MaxLightStrength));
        auto Min = min;
        auto Max = max;
        Min.value.Z = 0;
        Max.value.Z = 0;

        foreach(pos ; RangeFromTo(Min.value, Max.value)) {
            auto tilePos = getTopTilePos(TileXYPos(vec2i(pos.X, pos.Y)));
            tilePos.value.Z += 1;
            if(tilePos.value.Z >= min.value.Z && tilePos.value.Z <= max.value.Z) {
                tiles ~= tilePos;
            }
        }
        return tiles;
    }

}


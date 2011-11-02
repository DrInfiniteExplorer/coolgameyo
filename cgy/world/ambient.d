
module world.ambient;



mixin template LightStorageMethods() {

    private void addLight(LightSource light) {
        TilePos tp = TilePos(convert!int(light.position));

        aabbd aabb = tp.getAABB();
        aabb.scale(vec3d(0.4));
        addAABB(aabb, vec3f(0,0, 0.8));

        auto sectorNum = tp.getSectorNum;
        auto sector = getSector(sectorNum);
        enforce(sector !is null, "Cant add lights to sectors that dont exist you dummy!");
        sector.addLight(light);
        //auto min = TilePos(tp.value - vec3i(MaxLightStrength,MaxLightStrength,MaxLightStrength));
        //auto max = TilePos(tp.value + vec3i(MaxLightStrength,MaxLightStrength,MaxLightStrength));
        //recalculateLight(min, max);
        recalculateLight(tp);

    }
    void unsafeAddLight(LightSource light) {
        addLight(light);
    }

    void recalculateLight(TilePos centre) {
        recalculateLight(TilePos(centre.value-vec3i(MaxLightStrength, MaxLightStrength, MaxLightStrength)), 
                         TilePos(centre.value+vec3i(MaxLightStrength, MaxLightStrength, MaxLightStrength)));

        foreach(rel ; RangeFromTo(-1,1,-1, 1, -1, 1)) {
            notifyTileChange(TilePos(centre.value + rel*vec3i(MaxLightStrength,MaxLightStrength,MaxLightStrength)));
        }
    }

    void recalculateLight(TilePos min, TilePos max) {
        struct data {
            TilePos p;
            byte strength;
        }
        alias RedBlackTree!(data, q{a.p.value < b.p.value}) TileSet;

        foreach(rel ; RangeFromTo (min.value, max.value)) {
            auto tp = TilePos(rel);
            //Tile tile = getTile(tp);
            //tile.lightValue = 0;
            //setTile(tp, tile); //We dont care about sending changes for this. It is calculated clientside anyway.
            setTileLightVal(tp, 0, false); //We dont care about sending changes for this. It is calculated clientside anyway.
        }
        auto lights = getAffectingLights(min, max);


        TileSet open = new TileSet;
        foreach(light ; lights) {
            auto startTile = TilePos(convert!int(light.position));
            open.insert(data(startTile, light.strength));
        }
        TileSet current= new TileSet;
        TileSet closed = new TileSet;
        while (!open.empty) {
            swap(open, current);
            while (!current.empty) {
                auto d = current.removeAny();
                closed.insert(d);
                auto tilePos = d.p;
                auto tile = getTile(tilePos);
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
                    auto tmp = data(neighbor, 0);
                    if(!(tmp in closed) && !(tmp in current)){
                        open.insert(data(neighbor, cast(byte)(d.strength-1)));
                    }
                }
            }
        }

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
}


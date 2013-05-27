module graphics.tilegeometry;


import core.sync.mutex;

import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.exception;
import std.math;
import std.stdio;
import std.string;
version(Windows) import std.c.windows.windows; //TODO: What uses this?

import derelict.opengl.gl;
import derelict.opengl.glext;


import changes.worldproxy;
import graphics.camera;
import graphics.debugging;
import graphics.renderer;
import graphics.tilerenderer;
import light;
import modules.module_;
import util.pos;
import scheduler;
import settings;
import statistics;
import stolen.aabbox3d;

import worldstate.worldstate;

import util.intersect;
import util.memory;
import util.rangefromto;
import util.util;

alias util.util.Direction Direction;

immutable GraphRegionsPerTick = 4;




class TileFaces {

    GRFace[] faces;
    bool available;
    debug ptrdiff_t thread;

    this() {
        faces.reserve(100);
        faces.length = faces.capacity();
        available = true;
    }

    void clear() {
        //msg("Clearing");
        available = true;
        faces.length = 0;
        assumeSafeAppend(faces);
    }
    void append(ref GRFace face) {
        debug BREAK_IF(workerID != thread);
        debug auto cap = faces.capacity();
        faces ~= face; //Ugh!
        debug{
            if(cap != faces.capacity()) {
                msg("Increased capacity to ", faces.capacity());
            }
        }
    }
}

__gshared TileFaces[GraphRegionsPerTick] tileFaces;
__gshared Mutex tileFaceMutex;

shared static this() {
    tileFaceMutex = new Mutex();
    foreach(idx, tf ; tileFaces) {
        tileFaces[idx] = new TileFaces();
    }
}

TileFaces getTileFaces() {
    synchronized(tileFaceMutex) {
        int c = 0;
        while(true) {
            if(tileFaces[c].available) {
                tileFaces[c].available = false;
                debug tileFaces[c].thread = workerID;
                //msg("Returning tileface ", c);
                return tileFaces[c];
            }
            c = (c+1) % GraphRegionsPerTick;
        }
    }
}

struct GRVertex{
    vec3f vertex;
    vec3f texcoord;
    float normal = 0;
    float lightValue = 0;
    float sunLightValue = 0;
};

struct GRFace{
    GRVertex[4] quad;
}


const(string) FixLighting_get(int num, int dir, int which) {
    int div, mod;
    div = (which/3) -1;
    mod = (which%3) -1;
    if(num == 0) { //X
        return text(dir, ", ", div, ", ", mod);
    } else if(num == 1) { //Y
        return text(div, ", ", dir, ", ", mod);
    } else if(num == 2) { //Z
        return text(div, ", ", mod, ", ", dir);
    }
    assert(0); 
}

template FixLighting(const string A, const int num, const int dir, const string one, const string two, const string three, const string four) {

    /*
    static if (sunLight) {
    enum lighting = "sunLightValue";
    } else {
    enum lighting = "lightValue";
    }
    */

    enum lighting = "lightValue";

    //This is used to get a vertex index based on stuff like "UH". one-two-three-four is different
    // for different orientations to fix lighting.

    enum vertIndex = [ one : "0", two : "1", three : "2", four : "3" ];

    const char[] FixLighting = "
        if(0 == smoothMethod) {
        newFace.quad[0].sunLightValue = tile" ~ A ~ ".sunLightValue / cast(float)MaxLightStrength;
        newFace.quad[0].lightValue = tile" ~ A ~ ".lightValue / cast(float)MaxLightStrength;
        newFace.quad[1].sunLightValue = tile" ~ A ~ ".sunLightValue / cast(float)MaxLightStrength;
        newFace.quad[1].lightValue = tile" ~ A ~ ".lightValue / cast(float)MaxLightStrength;
        newFace.quad[2].sunLightValue = tile" ~ A ~ ".sunLightValue / cast(float)MaxLightStrength;
        newFace.quad[2].lightValue = tile" ~ A ~ ".lightValue / cast(float)MaxLightStrength;
        newFace.quad[3].sunLightValue = tile" ~ A ~ ".sunLightValue / cast(float)MaxLightStrength;
        newFace.quad[3].lightValue = tile" ~ A ~ ".lightValue / cast(float)MaxLightStrength;
        } else if ( smoothMethod == 1 ) {
        //*
        float v00  = world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 0) ~ "))).lightValue;
        float v00s = world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 0) ~ "))).sunLightValue;
        float v01  = world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 1) ~ "))).lightValue;
        float v01s = world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 1) ~ "))).sunLightValue;
        float v02  = world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 2) ~ "))).lightValue;
        float v02s = world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 2) ~ "))).sunLightValue;
        float v10  = world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 3) ~ "))).lightValue;
        float v10s = world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 3) ~ "))).sunLightValue;
        float v11  = tile" ~ A ~ ".lightValue;
        float v11s = tile" ~ A ~ ".sunLightValue;
        float v12  = world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 5) ~ "))).lightValue;
        float v12s = world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 5) ~ "))).sunLightValue;
        float v20  = world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 6) ~ "))).lightValue;
        float v20s = world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 6) ~ "))).sunLightValue;
        float v21  = world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 7) ~ "))).lightValue;
        float v21s = world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 7) ~ "))).sunLightValue;
        float v22  = world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 8) ~ "))).lightValue;
        float v22s = world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 8) ~ "))).sunLightValue;

        newFace.quad[" ~ vertIndex["UH"] ~ "].lightValue = (v02 +v01 +v12 +v11 )/(4.0*MaxLightStrength); //UH
        newFace.quad[" ~ vertIndex["UH"] ~ "].sunLightValue = (v02s+v01s+v12s+v11s)/(4.0*MaxLightStrength); //UH
        newFace.quad[" ~ vertIndex["LH"] ~ "].lightValue = (v01 +v00 +v11 +v10 )/(4.0*MaxLightStrength); //LH
        newFace.quad[" ~ vertIndex["LH"] ~ "].sunLightValue = (v01s+v00s+v11s+v10s)/(4.0*MaxLightStrength); //LH
        newFace.quad[" ~ vertIndex["LF"] ~ "].lightValue = (v11 +v10 +v21 +v20 )/(4.0*MaxLightStrength); //LF
        newFace.quad[" ~ vertIndex["LF"] ~ "].sunLightValue = (v11s+v10s+v21s+v20s)/(4.0*MaxLightStrength); //LF
        newFace.quad[" ~ vertIndex["UF"] ~ "].lightValue = (v12 +v11 +v22 +v21 )/(4.0*MaxLightStrength); //UF
        newFace.quad[" ~ vertIndex["UF"] ~ "].sunLightValue = (v12s+v11s+v22s+v21s)/(4.0*MaxLightStrength); //UF
        //*/
        } else if ( smoothMethod == 2 ) {
        /*
        auto t00= world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 0) ~ ")));
        auto t01= world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 1) ~ ")));
        auto t02= world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 2) ~ ")));
        auto t10= world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 4) ~ ")));
        auto t11= tile" ~ A ~ ";
        auto t12= world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 5) ~ ")));
        auto t20= world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 6) ~ ")));
        auto t21= world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 7) ~ ")));
        auto t22= world.getTile(TilePos(pos+vec3i(" ~ FixLighting_get(num, dir, 8) ~ ")));

        float v00 = t00.isAir ? t00." ~ lighting ~ " : 0;
        float v01 = t01.isAir ? t01." ~ lighting ~ " : 0;
        float v02 = t02.isAir ? t02." ~ lighting ~ " : 0;
        float v10 = t10.isAir ? t10." ~ lighting ~ " : 0;
        float v11 = t11.isAir ? t11." ~ lighting ~ " : 0;
        float v12 = t12.isAir ? t12." ~ lighting ~ " : 0;
        float v20 = t20.isAir ? t20." ~ lighting ~ " : 0;
        float v21 = t21.isAir ? t21." ~ lighting ~ " : 0;
        float v22 = t22.isAir ? t22." ~ lighting ~ " : 0;

        newFace.quad[" ~ vertIndex["UH"] ~ "]." ~ lighting ~ " = (v02+v01+v12+v11)/(count(t02.isAir, t01.isAir, t12.isAir)*MaxLightStrength); //UH
        newFace.quad[" ~ vertIndex["LH"] ~ "]." ~ lighting ~ " = (v01+v00+v11+v10)/(count(t01.isAir, t00.isAir, t10.isAir)*MaxLightStrength); //LH
        newFace.quad[" ~ vertIndex["LF"] ~ "]." ~ lighting ~ " = (v11+v10+v21+v20)/(count(t10.isAir, t21.isAir, t20.isAir)*MaxLightStrength); //LF
        newFace.quad[" ~ vertIndex["UF"] ~ "]." ~ lighting ~ " = (v12+v11+v22+v21)/(count(t12.isAir, t22.isAir, t21.isAir)*MaxLightStrength); //UF
        //*/
        }
        ";
}

final class TileGeometry : Module, WorldStateListener
{
    static struct NumWrapper {
        GraphRegionNum num;
        TileGeometry geom;

        this(GraphRegionNum num_, TileGeometry geom_) {
            num = num_;
            geom = geom_;
            assert (geom !is null);
        }
        void taskFunc(WorldProxy world) {
            geom.buildGraphicsRegion(num);
        }
    }

    NumWrapper[GraphRegionsPerTick] taskedRegions;

    GraphRegionNum[] regionsToUpdate; //Only used in taskFunc and where we populate it, mutually exclusive locations.

    Mutex updateMutex;

    Camera camera;
    TileRenderer tileRenderer;
    WorldState world;

    this(WorldState w, TileRenderer _tileRenderer)
    {
        world = w;
        tileRenderer = _tileRenderer;
        world.addListener(this);
        updateMutex = new Mutex;
    }
    
    void destroy() {
        world.removeListener(this);
    }

    void setCamera(Camera cam) {
        camera = cam;
    }

    auto buildGeometry(TilePos min, TilePos max) {
        int smoothMethod = renderSettings.smoothSetting;
        TileFaces tileFaces = getTileFaces();

        GRFace newFace;
        newFace.quad[0].sunLightValue = 1.0;
        newFace.quad[0].lightValue = 0.5;
        newFace.quad[1].sunLightValue = 1.0;
        newFace.quad[1].lightValue = 0.5;
        newFace.quad[2].sunLightValue = 1.0;
        newFace.quad[2].lightValue = 0.5;
        newFace.quad[3].sunLightValue = 1.0;
        newFace.quad[3].lightValue = 0.5;
        vec3f tileTexSize = settings.getTileCoordSize();
        void fixTex(bool side, bool upper)(ref GRFace f, const(Tile) t, Direction normalDir){
            ushort tileId;
            static if (side) {
                tileId = world.tileTypeManager.byID(t.type).textures.side;
            } else static if(upper) {
                tileId = world.tileTypeManager.byID(t.type).textures.top;
            } else {
                tileId = world.tileTypeManager.byID(t.type).textures.bottom;
            }
            vec3f tileTexCoord = settings.getTileCoords(tileId);
            foreach(ref vert ; f.quad){
                vert.texcoord = vert.texcoord * tileTexSize + tileTexCoord;
                //vert.lightValue = 0.0f;
                vert.normal = normalDir;
            }
        }

        float count(bool a, bool b, bool c) {
            return 1 + (a?1:0) + (b?1:0) + (c?1:0);
        }


        //Will iterate trough all tiles within this graphregion.
        //TODO: Implement a method in world, which returns a collection of all tiles
        // within a specified area, for fast access instead of getTile all the time.
        foreach( pos ; RangeFromTo (min.value, max.value)) {
            auto tile = world.getTile(TilePos(pos));
            newFace.quad[0].lightValue = 0;
           if (!tile.valid)  {
                continue;
            }
            if (tile.isAir) {
                continue;
            }            
            auto tileXp = world.getTile(TilePos(pos+vec3i(1,0,0)));
            auto tileXn = world.getTile(TilePos(pos-vec3i(1,0,0)));
            auto tileYp = world.getTile(TilePos(pos+vec3i(0,1,0)));
            auto tileYn = world.getTile(TilePos(pos-vec3i(0,1,0)));
            auto tileZp = world.getTile(TilePos(pos+vec3i(0,0,1)));
            auto tileZn = world.getTile(TilePos(pos-vec3i(0,0,1)));
            //To generate where is invalid tiles, replace == with <=
            bool Xp;
            bool Xn;
            bool Yp;
            bool Yn;
            bool Zp;
            bool Zn;
            if (renderSettings.renderInvalidTiles) {
                Xp = tileXp.type <= TileTypeAir;
                Xn = tileXn.type <= TileTypeAir;
                Yp = tileYp.type <= TileTypeAir;
                Yn = tileYn.type <= TileTypeAir;
                Zp = tileZp.type <= TileTypeAir;
                Zn = tileZn.type <= TileTypeAir;
            } else {
                Xp = tileXp.isAir;
                Xn = tileXn.isAir;
                Yp = tileYp.isAir;
                Yn = tileYn.isAir;
                Zp = tileZp.isAir;
                Zn = tileZn.isAir;
            }
            auto x = pos.x;
            auto y = pos.y;
            auto z = pos.z;
            if (Xp) {
                newFace.quad[0].vertex.set(x+1, y, z+1); //Upper 'hither' corner
                newFace.quad[1].vertex.set(x+1, y, z); //Lower 'hither' corner
                newFace.quad[2].vertex.set(x+1, y+1, z); //Lower farther corner
                newFace.quad[3].vertex.set(x+1, y+1, z+1); //upper farther corner
                newFace.quad[0].texcoord.set(0, 0, 0);
                newFace.quad[1].texcoord.set(0, 1, 0);
                newFace.quad[2].texcoord.set(1, 1, 0);
                newFace.quad[3].texcoord.set(1, 0, 0);
                fixTex!(true, false)(newFace, tile, Direction.eastCount);
                mixin(FixLighting!("Xp", 0, 1, "UH", "LH", "LF", "UF"));

                tileFaces.append(newFace);
            }
            if (Xn) {
                newFace.quad[0].vertex.set(x, y, z); //Lower hither
                newFace.quad[1].vertex.set(x, y, z+1); //Upper hither
                newFace.quad[2].vertex.set(x, y+1, z+1); //Upper farther
                newFace.quad[3].vertex.set(x, y+1, z); //Lower farther
                newFace.quad[0].texcoord.set(0, 1, 0);
                newFace.quad[1].texcoord.set(0, 0, 0);
                newFace.quad[2].texcoord.set(1, 0, 0);
                newFace.quad[3].texcoord.set(1, 1, 0);
                fixTex!(true, false)(newFace, tile, Direction.westCount);
                mixin(FixLighting!("Xn", 0,-1, "LH", "UH", "UF", "LF"));

                tileFaces.append(newFace);
            }
            if (Yp) {
                newFace.quad[0].vertex.set(x, y+1, z); //Lower hither
                newFace.quad[1].vertex.set(x, y+1, z+1); //Upper hither
                newFace.quad[2].vertex.set(x+1, y+1, z+1); //Upper farther
                newFace.quad[3].vertex.set(x+1, y+1, z); //Lower father
                newFace.quad[0].texcoord.set(0, 1, 0);
                newFace.quad[1].texcoord.set(0, 0, 0);
                newFace.quad[2].texcoord.set(1, 0, 0);
                newFace.quad[3].texcoord.set(1, 1, 0);
                fixTex!(true, false)(newFace, tile, Direction.northCount);
                mixin(FixLighting!("Yp", 1, 1, "LH", "UH", "UF", "LF"));

                tileFaces.append(newFace);
            }
            if (Yn) {
                newFace.quad[0].vertex.set(x, y, z+1); //Hither upper
                newFace.quad[1].vertex.set(x, y, z); //Hither lower
                newFace.quad[2].vertex.set(x+1, y, z); //Father lower
                newFace.quad[3].vertex.set(x+1, y, z+1); //Father uper
                newFace.quad[0].texcoord.set(0, 0, 0);
                newFace.quad[1].texcoord.set(0, 1, 0);
                newFace.quad[2].texcoord.set(1, 1, 0);
                newFace.quad[3].texcoord.set(1, 0, 0);
                fixTex!(true, false)(newFace, tile, Direction.southCount);
                mixin(FixLighting!("Yn", 1,-1, "UH", "LH", "LF", "UF"));

                tileFaces.append(newFace);
            }
            if (Zp) {
                newFace.quad[0].vertex.set(x, y+1, z+1); //Hither upper
                newFace.quad[1].vertex.set(x, y, z+1); //Hither lower
                newFace.quad[2].vertex.set(x+1, y, z+1); //Farther lower
                newFace.quad[3].vertex.set(x+1, y+1, z+1); //Farther upper
                newFace.quad[0].texcoord.set(0, 0, 0);
                newFace.quad[1].texcoord.set(0, 1, 0);
                newFace.quad[2].texcoord.set(1, 1, 0);
                newFace.quad[3].texcoord.set(1, 0, 0);
                fixTex!(false, true)(newFace, tile, Direction.upCount);
                mixin(FixLighting!("Zp", 2, 1, "UH", "LH", "LF", "UF"));

                tileFaces.append(newFace);
            }
            if (Zn) {
                newFace.quad[0].vertex.set(x, y, z); //hiether lower
                newFace.quad[1].vertex.set(x, y+1, z); //hither upper
                newFace.quad[2].vertex.set(x+1, y+1, z); //father upper
                newFace.quad[3].vertex.set(x+1, y, z); //father lower
                newFace.quad[0].texcoord.set(0, 0, 0);
                newFace.quad[1].texcoord.set(0, 1, 0);
                newFace.quad[2].texcoord.set(1, 1, 0);
                newFace.quad[3].texcoord.set(1, 0, 0);
                fixTex!(false, false)(newFace, tile, Direction.downCount);
                mixin(FixLighting!("Zn", 2,-1, "LH", "UH", "UF", "LF"));

                tileFaces.append(newFace);
            }
        }
        return tileFaces;
    }
    


    
    void buildGraphicsRegion(GraphRegionNum grNum){
        mixin(LogTime!("BuildGeometry"));        
        g_Statistics.GraphRegionsProgress(1);

        auto min = grNum.min();
        auto max = grNum.max();
        auto tileFaces = buildGeometry(min, max);

        //TODO: Fix so that this is not needed anylonger.
        foreach(ref face ; tileFaces.faces) { 
            foreach(ref vert ; face.quad) {
                vert.vertex -= min.value.convert!float();
            }
        }

        tileRenderer.updateGeometry(grNum, tileFaces);
    }

    override void serializeModule() { 
        //Do nothing. Rebuild geometry when loading instead.
        //TODO: In the future, examine saving of polygon data.
    }
    
    override void deserializeModule() { 
        //Tightly linked to the one above.
        //BREAKPOINT;
    }

    override void update(WorldState world, Scheduler scheduler) { // Module interface
        updateMutex.lock();
        scope(exit) updateMutex.unlock();

        if(regionsToUpdate.length == 0){
            g_Statistics.GraphRegionsNew(0);
            return;
        }
        
        mixin(LogTime!("MakeGeometryTasks"));

        double computeValue(GraphRegionNum num) {
            const auto graphRegionAcross = sqrt(to!double(  GraphRegionSize.x*GraphRegionSize.x +
                                                            GraphRegionSize.y*GraphRegionSize.y +
                                                            GraphRegionSize.z*GraphRegionSize.z));
            auto camDir = camera.getTargetDir().convert!double();
            auto camPos = camera.getPosition() - camDir * graphRegionAcross;
            vec3d toBlock = num.toTilePos().value.convert!double - camPos;
            double distSQ = toBlock.getLengthSQ();
            if(camDir.dotProduct(toBlock) < 0) {
                distSQ +=1000; //Stuff behind our backs are considered as important as stuff a kilometer ahead of us. ? :)
            }
            return distSQ;
        }

        //TODO: Do not sort every tick in the future.
        schwartzSort!(computeValue, "a>b")(regionsToUpdate);
        //writeln("before ", regionsToUpdate.length);
        auto len = regionsToUpdate.length;
        regionsToUpdate = array(uniq(regionsToUpdate));
        auto diff = len - regionsToUpdate.length;
        if(diff != 0) {
            g_Statistics.GraphRegionsProgress(cast(int)diff);
        }
        //writeln("after ", regionsToUpdate.length);        
        
        auto cnt = min(regionsToUpdate.length, GraphRegionsPerTick);
        enforce(cnt > 0, "Do not get here. In fact, it is impossible!");
        auto nums = regionsToUpdate[$-cnt .. $].array; //Lol was not safe to assumesafeappend until added dup, i think?
        regionsToUpdate.length -= cnt;
        assumeSafeAppend(regionsToUpdate); //Pretty safe yes

        foreach(i, num; nums) {
            taskedRegions[i] = NumWrapper(num, this);
            scheduler.push(task(&taskedRegions[i].taskFunc));
        }
    }

    bool solidNearAirBorder(GraphRegionNum grNum) {
        auto minTilePos = grNum.min;
        auto maxTilePos = grNum.max();
        return world.solidNearAirBorder(minTilePos, maxTilePos);
    }

    void onAddUnit(SectorNum, Unit) { }
    void onAddEntity(SectorNum, Entity) { }

    void onBuildGeometry(SectorNum sectorNum) {
        //version(Windows) auto start = GetTickCount();
        auto grNumMin = sectorNum.toTilePos().getGraphRegionNum();
        sectorNum.value += vec3i(1,1,1);
        auto tmp = sectorNum.toTilePos();
        tmp.value -= vec3i(1,1,1);
        auto grNumMax = tmp.getGraphRegionNum();
        sectorNum.value -= vec3i(1,1,1);

        //TODO: figure out what kind of problems i was referring to.
        //ASSUMES THAT WE ARE IN THE UPDATE PHASE, OTHERWISE THIS MAY INTRODUCE PROBLEMS AND SUCH. :)
        //*
        assert (this !is null);
        GraphRegionNum[] newRegions;
        foreach(pos ; RangeFromTo (grNumMin.value, grNumMax.value)) {
            auto grNum = GraphRegionNum(pos);
            if(solidNearAirBorder(grNum)){
                //msg("Has content;", grNum);
                newRegions ~= grNum;
            }
        }
        if(newRegions.length != 0){
            updateMutex.lock();
            scope(exit) updateMutex.unlock();
            g_Statistics.GraphRegionsNew(cast(int)newRegions.length);
            regionsToUpdate ~= newRegions;
        }
    }
    
    void onSectorUnload(SectorNum sectorNum) {
        tileRenderer.removeSector(sectorNum);
        updateMutex.lock();
        scope(exit) updateMutex.unlock();
        int removedCount = 0;
        int count = cast(int)regionsToUpdate.length;
        for(int i = 0; i < count; i++) {
            if(regionsToUpdate[i].getSectorNum() == sectorNum) {
                regionsToUpdate[i] = regionsToUpdate[$-1];
                count--;
                removedCount++;
            }
        }
        if(removedCount > 0) {
            regionsToUpdate.length = count;
            assumeSafeAppend(regionsToUpdate);
            g_Statistics.GraphRegionsProgress(removedCount);
        }

    }
    override void onUpdateGeometry(TilePos tilePos) {
        GraphRegionNum[] newRegions;
        auto tileAABB = tilePos.getAABB();

        newRegions ~= tilePos.getGraphRegionNum();
        //Check neighboring graphregions as well.
        newRegions ~= tilePos.getNeighboringGraphRegionNums();

        updateMutex.lock();
        scope(exit) updateMutex.unlock();
        regionsToUpdate ~= newRegions;
    }

    override void onTileChange(TilePos tilePos) {
        onUpdateGeometry(tilePos);
    }
    override void onSectorLoad(SectorNum sectorNum) {
        onBuildGeometry(sectorNum);
    }

}


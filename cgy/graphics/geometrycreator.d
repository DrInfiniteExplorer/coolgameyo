module graphics.geometrycreator;

pragma(msg, "> geometrycreator.d");        

import core.sync.mutex;

import std.algorithm;
import std.array;
import std.container;
import std.conv;
import std.datetime;
import std.exception;
import std.math;
import std.stdio;
import std.string;
version(Windows) import std.c.windows.windows; //TODO: What uses this?

import derelict.opengl.gl;
import derelict.opengl.glext;


import graphics.camera;
import graphics.debugging;
import graphics.renderer;
import light;
import modules.module_;
import pos;
import scheduler;
import settings;
import statistics;
import stolen.aabbox3d;

import world.world;
import util.util;
import util.rangefromto;
import util.intersect;

alias util.util.Direction Direction;

struct GraphicsRegion
{
    GraphRegionNum grNum;
    uint VBO = 0;
    uint quadCount = 0;
    GRFace[] faces;
}

struct GRVertex{
    vec3f vertex;
    vec3f texcoord;
    float normal = 0;
    float light = 0;
    float sunLight = 0;
};

struct GRFace{
    GRVertex[4] quad;
}


static const(string) FixLighting_map(const(string) one, const(string) two, const(string) three, const(string) four,
    const(string) key)() {
    static if(key == one) return "0";
    static if(key == two) return "1";
    static if(key == three) return "2";
    static if(key == four) return "3";
}
static const(string) FixLighting_get(int num, int dir, int which) {
    string[int] map = [ 0 : "0", 1 : "1", 2 : "2", -1 : "-1"];
    int div, mod;
    div = (which/3) -1;
    mod = (which%3) -1;
    if(num == 0) { //X
        //return format("%d, %d, %d", dir, which/3, mod);
        return text(map[dir], ", ", map[div], ", ", map[mod]);
    } else if(num == 1) { //Y
        //return format("%d, %d, %d", div, dir, mod);
        return text(map[div], ", ", map[dir], ", ", map[mod]);
    } else if(num == 2) { //Z
        //return format("%d, %d, %d", div, mod, dir);
        return text(map[div], ", ", map[mod], ", ", map[dir]);
    }
    assert(0);
}

static const(string) FixLighting_index(const bool sunLight, const int which)() {
    static if(which == 0) {
        return sunLight ? "sunLightValue" : "lightValue";
    }
    static if(which == 1) {
        return sunLight ? "sunLight" : "light";
    }
}

template FixLighting(const string A, const int num, const int dir, const string one, const string two, const string three, const string four, const bool sunLight) {

    const char[] FixLighting = text("
                                    if(0 == smoothMethod) {
                                    newFace.quad[0].",FixLighting_index!(sunLight, 1)," = tile",A,".",FixLighting_index!(sunLight, 0),"/cast(float)MaxLightStrength;
                                    newFace.quad[1].",FixLighting_index!(sunLight, 1)," = tile",A,".",FixLighting_index!(sunLight, 0),"/cast(float)MaxLightStrength;
                                    newFace.quad[2].",FixLighting_index!(sunLight, 1)," = tile",A,".",FixLighting_index!(sunLight, 0),"/cast(float)MaxLightStrength;
                                    newFace.quad[3].",FixLighting_index!(sunLight, 1)," = tile",A,".",FixLighting_index!(sunLight, 0),"/cast(float)MaxLightStrength;
                                    } else if ( 1 == smoothMethod) {
                                    float v00 = world.getTile(TilePos(pos+vec3i(",FixLighting_get(num, dir, 0),")), false).",FixLighting_index!(sunLight, 0),";
                                    float v01 = world.getTile(TilePos(pos+vec3i(",FixLighting_get(num, dir, 1),")), false).",FixLighting_index!(sunLight, 0),";
                                    float v02 = world.getTile(TilePos(pos+vec3i(",FixLighting_get(num, dir, 2),")), false).",FixLighting_index!(sunLight, 0),";
                                    float v10 = world.getTile(TilePos(pos+vec3i(",FixLighting_get(num, dir, 3),")), false).",FixLighting_index!(sunLight, 0),";
                                    float v11 = tile",A,".",FixLighting_index!(sunLight, 0),";
                                    float v12 = world.getTile(TilePos(pos+vec3i(",FixLighting_get(num, dir, 5),")), false).",FixLighting_index!(sunLight, 0),";
                                    float v20 = world.getTile(TilePos(pos+vec3i(",FixLighting_get(num, dir, 6),")), false).",FixLighting_index!(sunLight, 0),";
                                    float v21 = world.getTile(TilePos(pos+vec3i(",FixLighting_get(num, dir, 7),")), false).",FixLighting_index!(sunLight, 0),";
                                    float v22 = world.getTile(TilePos(pos+vec3i(",FixLighting_get(num, dir, 8),")), false).",FixLighting_index!(sunLight, 0),";

                                    newFace.quad[",FixLighting_map!(one,two,three,four,"UH"),"].",FixLighting_index!(sunLight, 1)," = (v02+v01+v12+v11)/(4.0*MaxLightStrength); //UH
                                    newFace.quad[",FixLighting_map!(one,two,three,four,"LH"),"].",FixLighting_index!(sunLight, 1)," = (v01+v00+v11+v10)/(4.0*MaxLightStrength); //LH
                                    newFace.quad[",FixLighting_map!(one,two,three,four,"LF"),"].",FixLighting_index!(sunLight, 1)," = (v11+v10+v21+v20)/(4.0*MaxLightStrength); //LF
                                    newFace.quad[",FixLighting_map!(one,two,three,four,"UF"),"].",FixLighting_index!(sunLight, 1)," = (v12+v11+v22+v21)/(4.0*MaxLightStrength); //UF
                                    } else if ( 2 == smoothMethod) {
                                    auto t00= world.getTile(TilePos(pos+vec3i(",FixLighting_get(num, dir, 0),")), false);
                                    auto t01= world.getTile(TilePos(pos+vec3i(",FixLighting_get(num, dir, 1),")), false);
                                    auto t02= world.getTile(TilePos(pos+vec3i(",FixLighting_get(num, dir, 2),")), false);
                                    auto t10= world.getTile(TilePos(pos+vec3i(",FixLighting_get(num, dir, 4),")), false);
                                    auto t11= tile",A,";
                                    auto t12= world.getTile(TilePos(pos+vec3i(",FixLighting_get(num, dir, 5),")), false);
                                    auto t20= world.getTile(TilePos(pos+vec3i(",FixLighting_get(num, dir, 6),")), false);
                                    auto t21= world.getTile(TilePos(pos+vec3i(",FixLighting_get(num, dir, 7),")), false);
                                    auto t22= world.getTile(TilePos(pos+vec3i(",FixLighting_get(num, dir, 8),")), false);

                                    float v00 = t00.isAir ? t00.",FixLighting_index!(sunLight, 0)," : 0;
                                    float v01 = t01.isAir ? t01.",FixLighting_index!(sunLight, 0)," : 0;
                                    float v02 = t02.isAir ? t02.",FixLighting_index!(sunLight, 0)," : 0;
                                    float v10 = t10.isAir ? t10.",FixLighting_index!(sunLight, 0)," : 0;
                                    float v11 = t11.isAir ? t11.",FixLighting_index!(sunLight, 0)," : 0;
                                    float v12 = t12.isAir ? t12.",FixLighting_index!(sunLight, 0)," : 0;
                                    float v20 = t20.isAir ? t20.",FixLighting_index!(sunLight, 0)," : 0;
                                    float v21 = t21.isAir ? t21.",FixLighting_index!(sunLight, 0)," : 0;
                                    float v22 = t22.isAir ? t22.",FixLighting_index!(sunLight, 0)," : 0;

                                    newFace.quad[",FixLighting_map!(one,two,three,four,"UH"),"].",FixLighting_index!(sunLight, 1)," = (v02+v01+v12+v11)/(count(t02.isAir, t01.isAir, t12.isAir)*MaxLightStrength); //UH
                                    newFace.quad[",FixLighting_map!(one,two,three,four,"LH"),"].",FixLighting_index!(sunLight, 1)," = (v01+v00+v11+v10)/(count(t01.isAir, t00.isAir, t10.isAir)*MaxLightStrength); //LH
                                    newFace.quad[",FixLighting_map!(one,two,three,four,"LF"),"].",FixLighting_index!(sunLight, 1)," = (v11+v10+v21+v20)/(count(t10.isAir, t21.isAir, t20.isAir)*MaxLightStrength); //LF
                                    newFace.quad[",FixLighting_map!(one,two,three,four,"UF"),"].",FixLighting_index!(sunLight, 1)," = (v12+v11+v22+v21)/(count(t12.isAir, t22.isAir, t21.isAir)*MaxLightStrength); //UF
                                    }
                                    ");
    // */
}


class GeometryCreator : Module, WorldListener
{
    GraphRegionNum[] regionsToUpdate; //Only used in taskFunc and where we populate it, mutually exclusive locations.
    GraphicsRegion[GraphRegionNum] regions; //Accessed from getRegions and from taskFunc, could collide.
    GraphRegionNum[] dirtyRegions; //Can be updated by worker thread; Is read&cleared in render thread.
    Mutex dirtyMutex;
    Mutex regionMutex;
    Mutex updateMutex;

    World world;
    Camera camera;
    double minReUseRatio;

    this(World w)
    {
        world = w;
        world.addListener(this);
        minReUseRatio = 0.95;
        regionMutex = new Mutex;
        dirtyMutex = new Mutex;
        updateMutex = new Mutex;
    }
    
    void destroy() {
        world.removeListener(this);
        removeAllVBOs();
    }

    void removeAllVBOs(){
        foreach(region ; regions){
            glDeleteBuffers(1, &region.VBO);
        }
        regions = null;
    }

    void setCamera(Camera cam) {
        camera = cam;
    }

    void buildGeometry(TilePos min, TilePos max, ref GRFace[]faceList)
    in{
        assert(min.value.X < max.value.X);
        assert(min.value.Y < max.value.Y);
        assert(min.value.Z < max.value.Z);
    }
    body{
        //Make floor triangles
        GRFace newFace;
        void fixTex(ref GRFace f, const(Tile) t, bool side, bool upper, Direction normalDir){
            ushort tileId;
            if (side) {
                tileId = world.tileTypeManager.byID(t.type).textures.side;
            } else {
                tileId = upper ? 
                    world.tileTypeManager.byID(t.type).textures.top :
                    world.tileTypeManager.byID(t.type).textures.bottom;
            }
            vec3f tileTexSize = settings.getTileCoordSize();
            vec3f tileTexCoord = settings.getTileCoords(tileId);
            foreach(ref vert ; f.quad){
                vert.texcoord = vert.texcoord * tileTexSize + tileTexCoord;
                //vert.light = cast(float)t.lightValue / cast(float)MaxLightStrength;
                vert.light = 0.f;
                vert.normal = normalDir;
            }
        }

        int smoothMethod = renderSettings.smoothSetting;
        float count(bool a, bool b, bool c) {
            return 1 + (a?1:0) + (b?1:0) + (c?1:0);
        }


        //Will iterate trough all tiles within this graphregion.
        //TODO: Implement a method in world, which returns a collection of all tiles
        // within a specified area, for fast access instead of getTile all the time.
        foreach( pos ; RangeFromTo (min.value, max.value)) {
            auto tile = world.getTile(TilePos(pos), false);
            newFace.quad[0].light = 0;
           if (!tile.valid)  {
                continue;
            }
            if (tile.isAir) {
                continue;
            }            
            if (!tile.seen) {
                continue;
            }
            auto tileXp = world.getTile(TilePos(pos+vec3i(1,0,0)), false);
            auto tileXn = world.getTile(TilePos(pos-vec3i(1,0,0)), false);
            auto tileYp = world.getTile(TilePos(pos+vec3i(0,1,0)), false);
            auto tileYn = world.getTile(TilePos(pos-vec3i(0,1,0)), false);
            auto tileZp = world.getTile(TilePos(pos+vec3i(0,0,1)), false);
            auto tileZn = world.getTile(TilePos(pos-vec3i(0,0,1)), false);
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
            auto x = pos.X;
            auto y = pos.Y;
            auto z = pos.Z;
            if (Xp) {
                newFace.quad[0].vertex.set(x+1, y, z+1); //Upper 'hither' corner
                newFace.quad[1].vertex.set(x+1, y, z); //Lower 'hither' corner
                newFace.quad[2].vertex.set(x+1, y+1, z); //Lower farther corner
                newFace.quad[3].vertex.set(x+1, y+1, z+1); //upper farther corner
                newFace.quad[0].texcoord.set(0, 0, 0);
                newFace.quad[1].texcoord.set(0, 1, 0);
                newFace.quad[2].texcoord.set(1, 1, 0);
                newFace.quad[3].texcoord.set(1, 0, 0);
                fixTex(newFace, tile, true, false, Direction.eastCount);
                /*
                if(0 == smoothMethod) {
                    newFace.quad[0].light = tileXp.lightValue/cast(float)MaxLightStrength;
                    newFace.quad[1].light = tileXp.lightValue/cast(float)MaxLightStrength;
                    newFace.quad[2].light = tileXp.lightValue/cast(float)MaxLightStrength;
                    newFace.quad[3].light = tileXp.lightValue/cast(float)MaxLightStrength;
                } else if ( 1 == smoothMethod) {
                    float v00 = world.getTile(TilePos(pos+vec3i(1,-1,-1)), false).lightValue;
                    float v01 = world.getTile(TilePos(pos+vec3i(1,-1, 0)), false).lightValue;
                    float v02 = world.getTile(TilePos(pos+vec3i(1,-1, 1)), false).lightValue;
                    float v10 = world.getTile(TilePos(pos+vec3i(1, 0,-1)), false).lightValue;
                    float v11 = tileXp.lightValue;
                    float v12 = world.getTile(TilePos(pos+vec3i(1, 0, 1)), false).lightValue;
                    float v20 = world.getTile(TilePos(pos+vec3i(1, 1,-1)), false).lightValue;
                    float v21 = world.getTile(TilePos(pos+vec3i(1, 1, 0)), false).lightValue;
                    float v22 = world.getTile(TilePos(pos+vec3i(1, 1, 1)), false).lightValue;

                    newFace.quad[0].light = (v02+v01+v12+v11)/(4.0*MaxLightStrength);
                    newFace.quad[1].light = (v01+v00+v11+v10)/(4.0*MaxLightStrength);
                    newFace.quad[2].light = (v11+v10+v21+v20)/(4.0*MaxLightStrength);
                    newFace.quad[3].light = (v12+v11+v22+v21)/(4.0*MaxLightStrength);
                } else if ( 2 == smoothMethod) {
                    auto t00= world.getTile(TilePos(pos+vec3i(1,-1,-1)), false);
                    auto t01= world.getTile(TilePos(pos+vec3i(1,-1, 0)), false);
                    auto t02= world.getTile(TilePos(pos+vec3i(1,-1, 1)), false);
                    auto t10= world.getTile(TilePos(pos+vec3i(1, 0,-1)), false);
                    auto t11= tileXp;
                    auto t12= world.getTile(TilePos(pos+vec3i(1, 0, 1)), false);
                    auto t20= world.getTile(TilePos(pos+vec3i(1, 1,-1)), false);
                    auto t21= world.getTile(TilePos(pos+vec3i(1, 1, 0)), false);
                    auto t22= world.getTile(TilePos(pos+vec3i(1, 1, 1)), false);

                    float v00 = t00.isAir ? t00.lightValue : 0;
                    float v01 = t01.isAir ? t01.lightValue : 0;
                    float v02 = t02.isAir ? t02.lightValue : 0;
                    float v10 = t10.isAir ? t10.lightValue : 0;
                    float v11 = t11.isAir ? t11.lightValue : 0;
                    float v12 = t12.isAir ? t12.lightValue : 0;
                    float v20 = t20.isAir ? t20.lightValue : 0;
                    float v21 = t21.isAir ? t21.lightValue : 0;
                    float v22 = t22.isAir ? t22.lightValue : 0;

                    newFace.quad[0].light = (v02+v01+v12+v11)/(count(t02.isAir, t01.isAir, t12.isAir)*MaxLightStrength);
                    newFace.quad[1].light = (v01+v00+v11+v10)/(count(t01.isAir, t00.isAir, t10.isAir)*MaxLightStrength);
                    newFace.quad[2].light = (v11+v10+v21+v20)/(count(t10.isAir, t21.isAir, t20.isAir)*MaxLightStrength);
                    newFace.quad[3].light = (v12+v11+v22+v21)/(count(t12.isAir, t22.isAir, t21.isAir)*MaxLightStrength);
                }*/

                mixin(FixLighting!("Xp", 0, 1, "UH", "LH", "LF", "UF", true));
                mixin(FixLighting!("Xp", 0, 1, "UH", "LH", "LF", "UF", false));

                faceList ~= newFace;
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
                fixTex(newFace, tile, true, false, Direction.westCount);
                /*
                if(0 == smoothMethod) {
                    newFace.quad[0].light = tileXn.lightValue/cast(float)MaxLightStrength;
                    newFace.quad[1].light = tileXn.lightValue/cast(float)MaxLightStrength;
                    newFace.quad[2].light = tileXn.lightValue/cast(float)MaxLightStrength;
                    newFace.quad[3].light = tileXn.lightValue/cast(float)MaxLightStrength;
                } else if ( 1 == smoothMethod) {

                    float v00 = world.getTile(TilePos(pos+vec3i(-1,-1,-1)), false).lightValue;
                    float v01 = world.getTile(TilePos(pos+vec3i(-1,-1, 0)), false).lightValue;
                    float v02 = world.getTile(TilePos(pos+vec3i(-1,-1, 1)), false).lightValue;
                    float v10 = world.getTile(TilePos(pos+vec3i(-1, 0,-1)), false).lightValue;
                    float v11 = tileXn.lightValue;
                    float v12 = world.getTile(TilePos(pos+vec3i(-1, 0, 1)), false).lightValue;
                    float v20 = world.getTile(TilePos(pos+vec3i(-1, 1,-1)), false).lightValue;
                    float v21 = world.getTile(TilePos(pos+vec3i(-1, 1, 0)), false).lightValue;
                    float v22 = world.getTile(TilePos(pos+vec3i(-1, 1, 1)), false).lightValue;

                    newFace.quad[0].light = (v01+v00+v11+v10)/(4.0*MaxLightStrength);
                    newFace.quad[1].light = (v02+v01+v12+v11)/(4.0*MaxLightStrength);
                    newFace.quad[2].light = (v12+v11+v22+v21)/(4.0*MaxLightStrength);
                    newFace.quad[3].light = (v11+v10+v21+v20)/(4.0*MaxLightStrength);
                }*/
                mixin(FixLighting!("Xn", 0,-1, "LH", "UH", "UF", "LF", true));
                mixin(FixLighting!("Xn", 0,-1, "LH", "UH", "UF", "LF", false));

                faceList ~= newFace;
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
                fixTex(newFace, tile, true, false, Direction.northCount);
                /*
                if(0 == smoothMethod) {
                    newFace.quad[0].light = tileYp.lightValue/cast(float)MaxLightStrength;
                    newFace.quad[1].light = tileYp.lightValue/cast(float)MaxLightStrength;
                    newFace.quad[2].light = tileYp.lightValue/cast(float)MaxLightStrength;
                    newFace.quad[3].light = tileYp.lightValue/cast(float)MaxLightStrength;
                } else if ( 1 == smoothMethod) {

                    float v00 = world.getTile(TilePos(pos+vec3i(-1, 1,-1)), false).lightValue;
                    float v01 = world.getTile(TilePos(pos+vec3i(-1, 1, 0)), false).lightValue;
                    float v02 = world.getTile(TilePos(pos+vec3i(-1, 1, 1)), false).lightValue;
                    float v10 = world.getTile(TilePos(pos+vec3i( 0, 1,-1)), false).lightValue;
                    float v11 = tileYp.lightValue;
                    float v12 = world.getTile(TilePos(pos+vec3i( 0, 1, 1)), false).lightValue;
                    float v20 = world.getTile(TilePos(pos+vec3i( 1, 1,-1)), false).lightValue;
                    float v21 = world.getTile(TilePos(pos+vec3i( 1, 1, 0)), false).lightValue;
                    float v22 = world.getTile(TilePos(pos+vec3i( 1, 1, 1)), false).lightValue;

                    newFace.quad[0].light = (v01+v00+v11+v10)/(4.0*MaxLightStrength);
                    newFace.quad[1].light = (v02+v01+v12+v11)/(4.0*MaxLightStrength);
                    newFace.quad[2].light = (v12+v11+v22+v21)/(4.0*MaxLightStrength);
                    newFace.quad[3].light = (v11+v10+v21+v20)/(4.0*MaxLightStrength);
                }
                */
                mixin(FixLighting!("Yp", 1, 1, "LH", "UH", "UF", "LF", true));
                mixin(FixLighting!("Yp", 1, 1, "LH", "UH", "UF", "LF", false));

                faceList ~= newFace;
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
                fixTex(newFace, tile, true, false, Direction.southCount);
                /*
                if(0 == smoothMethod) {
                    newFace.quad[0].light = tileYn.lightValue/cast(float)MaxLightStrength;
                    newFace.quad[1].light = tileYn.lightValue/cast(float)MaxLightStrength;
                    newFace.quad[2].light = tileYn.lightValue/cast(float)MaxLightStrength;
                    newFace.quad[3].light = tileYn.lightValue/cast(float)MaxLightStrength;
                } else if ( 1 == smoothMethod) {

                    float v00 = world.getTile(TilePos(pos+vec3i(-1,-1,-1)), false).lightValue;
                    float v01 = world.getTile(TilePos(pos+vec3i(-1,-1, 0)), false).lightValue;
                    float v02 = world.getTile(TilePos(pos+vec3i(-1,-1, 1)), false).lightValue;
                    float v10 = world.getTile(TilePos(pos+vec3i( 0,-1,-1)), false).lightValue;
                    float v11 = tileYn.lightValue;
                    float v12 = world.getTile(TilePos(pos+vec3i( 0,-1, 1)), false).lightValue;
                    float v20 = world.getTile(TilePos(pos+vec3i( 1,-1,-1)), false).lightValue;
                    float v21 = world.getTile(TilePos(pos+vec3i( 1,-1, 0)), false).lightValue;
                    float v22 = world.getTile(TilePos(pos+vec3i( 1,-1, 1)), false).lightValue;
                
                    newFace.quad[0].light = (v02+v01+v12+v11)/(4.0*MaxLightStrength);
                    newFace.quad[1].light = (v01+v00+v11+v10)/(4.0*MaxLightStrength);
                    newFace.quad[2].light = (v11+v10+v21+v20)/(4.0*MaxLightStrength);
                    newFace.quad[3].light = (v12+v11+v22+v21)/(4.0*MaxLightStrength);
                }*/
                mixin(FixLighting!("Yn", 1,-1, "UH", "LH", "LF", "UF", true));
                mixin(FixLighting!("Yn", 1,-1, "UH", "LH", "LF", "UF", false));

                faceList ~= newFace;
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
                fixTex(newFace, tile, false, true, Direction.upCount);
                /*
                if(0 == smoothMethod) {
                    newFace.quad[0].light = tileZp.lightValue/cast(float)MaxLightStrength;
                    newFace.quad[1].light = tileZp.lightValue/cast(float)MaxLightStrength;
                    newFace.quad[2].light = tileZp.lightValue/cast(float)MaxLightStrength;
                    newFace.quad[3].light = tileZp.lightValue/cast(float)MaxLightStrength;
                } else if ( 1 == smoothMethod) {
                    float v00 = world.getTile(TilePos(pos+vec3i(-1,-1, 1)), false).lightValue;
                    float v01 = world.getTile(TilePos(pos+vec3i(-1, 0, 1)), false).lightValue;
                    float v02 = world.getTile(TilePos(pos+vec3i(-1, 1, 1)), false).lightValue;
                    float v10 = world.getTile(TilePos(pos+vec3i( 0,-1, 1)), false).lightValue;
                    float v11 = tileZp.lightValue;
                    float v12 = world.getTile(TilePos(pos+vec3i( 0, 1, 1)), false).lightValue;
                    float v20 = world.getTile(TilePos(pos+vec3i( 1,-1, 1)), false).lightValue;
                    float v21 = world.getTile(TilePos(pos+vec3i( 1, 0, 1)), false).lightValue;
                    float v22 = world.getTile(TilePos(pos+vec3i( 1, 1, 1)), false).lightValue;
                    newFace.quad[0].light = (v02+v01+v12+v11)/(4.0*MaxLightStrength);
                    newFace.quad[1].light = (v01+v00+v11+v10)/(4.0*MaxLightStrength);
                    newFace.quad[2].light = (v11+v10+v21+v20)/(4.0*MaxLightStrength);
                    newFace.quad[3].light = (v12+v11+v22+v21)/(4.0*MaxLightStrength);
                }*/
                mixin(FixLighting!("Zp", 2, 1, "UH", "LH", "LF", "UF", true));
                mixin(FixLighting!("Zp", 2, 1, "UH", "LH", "LF", "UF", false));

                faceList ~= newFace;
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
                fixTex(newFace, tile, false, false, Direction.downCount);
                /*
                if(0 == smoothMethod) {
                    newFace.quad[0].light = tileZn.lightValue/cast(float)MaxLightStrength;
                    newFace.quad[1].light = tileZn.lightValue/cast(float)MaxLightStrength;
                    newFace.quad[2].light = tileZn.lightValue/cast(float)MaxLightStrength;
                    newFace.quad[3].light = tileZn.lightValue/cast(float)MaxLightStrength;
                } else if ( 1 == smoothMethod) {
                    float v00 = world.getTile(TilePos(pos+vec3i(-1,-1,-1)), false).lightValue;
                    float v01 = world.getTile(TilePos(pos+vec3i(-1, 0,-1)), false).lightValue;
                    float v02 = world.getTile(TilePos(pos+vec3i(-1, 1,-1)), false).lightValue;
                    float v10 = world.getTile(TilePos(pos+vec3i( 0,-1,-1)), false).lightValue;
                    float v11 = tileZn.lightValue;
                    float v12 = world.getTile(TilePos(pos+vec3i( 0, 1,-1)), false).lightValue;
                    float v20 = world.getTile(TilePos(pos+vec3i( 1,-1,-1)), false).lightValue;
                    float v21 = world.getTile(TilePos(pos+vec3i( 1, 0,-1)), false).lightValue;
                    float v22 = world.getTile(TilePos(pos+vec3i( 1, 1,-1)), false).lightValue;
                    newFace.quad[0].light = (v01+v00+v11+v10)/(4.0*MaxLightStrength);
                    newFace.quad[1].light = (v02+v01+v12+v11)/(4.0*MaxLightStrength);
                    newFace.quad[2].light = (v12+v11+v22+v21)/(4.0*MaxLightStrength);
                    newFace.quad[3].light = (v11+v10+v21+v20)/(4.0*MaxLightStrength);
                }
                */
                mixin(FixLighting!("Zn", 2,-1, "LH", "UH", "UF", "LF", true));
                mixin(FixLighting!("Zn", 2,-1, "LH", "UH", "UF", "LF", false));
                faceList ~= newFace;
            }
        }
    }
    
    



    const(GraphicsRegion)[GraphRegionNum] getRegions(){
        {
            dirtyMutex.lock();
            scope(exit) dirtyMutex.unlock();
            if(dirtyRegions.length) {
                mixin(LogTime!("GRUploadTime"));
                foreach(num; dirtyRegions){
                    regionMutex.lock();
                    scope(exit) regionMutex.unlock();
                    buildVBO(regions[num]);
                }
                dirtyRegions.length = 0;
            }
        }

        return regions;
    }

    void buildVBO(ref GraphicsRegion region){
        auto primitiveCount = region.faces.length;
        auto geometrySize = primitiveCount * GRFace.sizeof;
        region.quadCount = primitiveCount;

        scope(exit) region.faces.length = 0;
        if(region.VBO){
            //See if VBO is reusable.
            int bufferSize;
            glBindBuffer(GL_ARRAY_BUFFER, region.VBO);
            glGetBufferParameteriv(GL_ARRAY_BUFFER_ARB, GL_BUFFER_SIZE_ARB, &bufferSize);

            double ratio = to!double(geometrySize)/to!double(bufferSize);
            if(minReUseRatio <= ratio && ratio <= 1){
                glBufferSubData(GL_ARRAY_BUFFER, 0, geometrySize, region.faces.ptr);
                return;
            }else{
                //Delete old vbo
                glBindBuffer(GL_ARRAY_BUFFER, 0);
                glDeleteBuffers(1, &region.VBO);
                region.VBO = 0; //For all it's worth. Will create new one just below. :P
            }
        }
        if(geometrySize > 0){
            glGenBuffers(1, &region.VBO);
            glBindBuffer(GL_ARRAY_BUFFER, region.VBO);
            glBufferData(GL_ARRAY_BUFFER, geometrySize, region.faces.ptr, GL_STATIC_DRAW);
        } else {
            msg("GOT NOTHING FROM GRAPHREGION! >:( ", region.grNum);
        }
        //addAABB(region.grNum.getAABB());
    }

    void buildGraphicsRegion(GraphicsRegion region){
        mixin(LogTime!("BuildGeometry"));        
        g_Statistics.GraphRegionsProgress(1);
        
        auto min = region.grNum.min();
        auto max = region.grNum.max();
        buildGeometry(min, max, region.faces);
        /*buildGeometryX(min, max, region.faces);
        buildGeometryY(min, max, region.faces);
        //Floor
        buildGeometryZ(min, max, region.faces);
        */
        //TODO: Fix so that this is not needed anylonger.
        foreach(ref face ; region.faces) {
            foreach(ref vert ; face.quad) {
                vert.vertex -= util.util.convert!float(min.value);
            }
        }

        //Ordering the other way around caused race condition where the render-thread tried to build num X before it's data had been set.
        {
            regionMutex.lock();
            scope(exit) regionMutex.unlock();
            regions[region.grNum] = region;
        }
        {
            dirtyMutex.lock();
            scope(exit) dirtyMutex.unlock();
            dirtyRegions ~= region.grNum;
        }
    }

    void taskFunc(const(World) world, GraphRegionNum num) {
        //TODO: Maybe move geometry-building-timing to here?
        GraphicsRegion reg;
        reg.grNum = num;
        {
            regionMutex.lock();
            scope(exit) regionMutex.unlock();
            if(num in regions) {
                reg = regions[num];
                if(reg.faces.length > 0){ //If was duplicate and/or quickly reinserted, but not yet rendered, do not blargh the blargh again
                    return;
                }
            }
        }
        buildGraphicsRegion(reg);
    }

   
    override void serializeModule() {  // Module interface
        //Do nothing. Rebuild geometry when loading instead.
        //TODO: In the future, examine saving of polygon data.
    }
    
    override void deserializeModule() {  // Module interface
        //Tightly linked to the one above.
        //BREAKPOINT;
    }

    override void update(World world, Scheduler scheduler) { // Module interface
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
            auto camDir = util.util.convert!double(camera.getTargetDir());
            auto camPos = camera.getPosition() - camDir * graphRegionAcross;
            vec3d toBlock = util.util.convert!double(num.toTilePos().value) - camPos;
            double distSQ = toBlock.getLengthSQ();
            if(camDir.dotProduct(toBlock) < 0) {
                distSQ +=1000; //Stuff behind our backs are considered as important as stuff a kilometer ahead of us. ? :)
            }
            return distSQ;
        }

        //TODO: Do not sort every tick in the future.
        schwartzSort!(computeValue, "a>b")(regionsToUpdate);
        //writeln("before ", regionsToUpdate.length);
        regionsToUpdate = array(uniq(regionsToUpdate));
        //writeln("after ", regionsToUpdate.length);        
        
        enum GraphRegionsPerTick = 2;
        auto cnt = min(regionsToUpdate.length, GraphRegionsPerTick);
        assert(cnt > 0, "derp derp derp");
        auto nums = regionsToUpdate[$-cnt .. $];
        regionsToUpdate.length -= cnt;
        foreach(num ; nums) {
            //Trixy trick below; if we dont do this, the value num will be shared by all pushed tasks.
            (GraphRegionNum num){
                scheduler.push(asyncTask(
                    (const(World) world){
                        taskFunc(world, num);
                    }));
            }(num);
        }        
    }

    bool hasContent(GraphRegionNum grNum) {
        auto minTilePos = grNum.min;
        auto maxTilePos = grNum.max();
        return world.hasContent(minTilePos, maxTilePos);
    }

    void onAddUnit(SectorNum, Unit) { }
	void onAddEntity(SectorNum, Entity) { }

    void onBuildGeometry(SectorNum sectorNum)
    {
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
        GraphRegionNum[] newRegions;
        foreach(pos ; RangeFromTo (grNumMin.value, grNumMax.value)) {
            auto grNum = GraphRegionNum(pos);
            if(hasContent(grNum)){
                //msg("Has content;", grNum);
                newRegions ~= grNum;
            }
        }
        if(newRegions.length != 0){
            updateMutex.lock();
            scope(exit) updateMutex.unlock();
            g_Statistics.GraphRegionsNew(newRegions.length);
            regionsToUpdate ~= newRegions;
        }
    }
    
    void onSectorUnload(SectorNum sectorNum)
    {
        auto sectorAABB = sectorNum.getAABB();
        {
            GraphRegionNum[] toRemove;
            regionMutex.lock();
            scope(exit) regionMutex.unlock();
            foreach(region ; regions){
                if(intersectsExclusive(sectorAABB, region.grNum.getAABB())){
                    toRemove ~= region.grNum;
                    //msg("Unload stuff oh yeah!!");
                    //msg("Perhaps.. Should we.. Maybe.. Stora data on disk? We'll see how things turn out.");
                    //How to do stuff, et c?

                }
            }
            foreach(grNum ; toRemove) {
                glDeleteBuffers(1, &regions[grNum].VBO);
                regions.remove(grNum);
            }
        }
    }
    void onUpdateGeometry(TilePos tilePos)
    {
        GraphRegionNum[] newRegions;
        auto tileAABB = tilePos.getAABB();
        /*
        {
            regionMutex.lock();
            scope(exit) regionMutex.unlock();
            foreach(region ; regions){
                if(tileAABB.intersectsWithBox(region.grNum.getAABB())){
                    newRegions ~= region.grNum;
                }
            }
        }
        */

        //Example, we dug into a yet invisible area.
        //Maybe let the floodfill take care of it instead, somehow?
        //dunno. think it's needed here as well.
        //if(newRegions.length == 0) {
            newRegions ~= tilePos.getGraphRegionNum(); //Check neighboring graphregions as well.
            newRegions ~= tilePos.getNeighboringGraphRegionNums();
        //}
        updateMutex.lock();
        scope(exit) updateMutex.unlock();
        regionsToUpdate ~= newRegions;
    }

    void onTileChange(TilePos tilePos) {
        onUpdateGeometry(tilePos);
    }
    void onSectorLoad(SectorNum sectorNum) {
        onBuildGeometry(sectorNum);
    }

}

pragma(msg, "< geometrycreator.d");        

module worldgen.worldgen;

import std.math, std.conv, std.random, std.algorithm;
import std.c.process;
import std.stdio;

import tiletypemanager;
import world;
import util;
import pos;
import graphics.texture;
import graphics.debugging;

struct WorldGenParams {
    uint randomSeed = 880128;
    uint worldSize = 8; //Measures diameter of world, in number of sectors.
    //TODO: Heightlimits as parameter?
}

/*
private float foo(float x, float y) {
//    return 4*sin(x/10.0) + 24*atan(y/50.0) - 2*cos(y/3.0);
//    return 4*sin(x/10.f) - 2*cos(y/13.f);
    return 4*sin(x/10.0) + 24*atan(y/50.0);
}
*/

interface WorldGenerator {
    void init(WorldGenParams params, TileTypeManager tileTypeManager);
    Tile getTile(TilePos pos);
    int maxZ(const TileXYPos xypos);
    
    void destroy();
}

final class WorldGeneratorOld : WorldGenerator{
    TileTypeManager sys;

    uint randMap[512][512];

    ushort air, mud, rock, water;

    void destroy() {
        //Nothing here yet.
    }
    
    void init(WorldGenParams params, TileTypeManager tileTypeManager) {
        sys = tileTypeManager;
        air = sys.idByName("air");
        mud = sys.idByName("mud");
        rock = sys.idByName("rock");
        water = sys.idByName("water");
        Random gen;
        gen.seed(880128);
        foreach(x ; 0 .. 512){
            foreach(y ; 0 .. 512){
                randMap[x][y] = uniform(0, uint.max, gen);
            }
        }

        version(saveHeightmap){
            ubyte[] imgData;
            imgData.length = 4*512*512;
            foreach(x ; 0 .. 512){
                foreach(y ; 0 .. 512){
                    //ubyte v = cast(ubyte)(foo(x-256,y-256) * 255.f / 25.f);
                    auto d = TileXYPos(vec2i(x-256, y-256));
                    ubyte v = cast(ubyte)(maxZ(d) * 10);
                    imgData[4*(y*512+x)+0] = v;
                    imgData[4*(y*512+x)+1] = v;
                    imgData[4*(y*512+x)+2] = v;
                    imgData[4*(y*512+x)+3] = 255u;
                }
            }
            auto img = Image(imgData.ptr, 512u, 512u);
            img.save("heightmap.png");
            version(onlySaveHeightmap){
                system("start heightmap.png");
                exit(0);
            }
        }        
    }


    float get(float x, float y, float freq){
        x *= freq;
        y *= freq;
        int loX = to!int(floor(x));
        int loY = to!int(floor(y));
        float get(int x, int y){
            x = posMod(x, 512);
            y = posMod(y, 512);
            return to!float(to!double(randMap[x][y]) / to!double(uint.max));
        }
        float dX = x - to!float(loX);
        float dY = y - to!float(loY);
        float cinterpolate(float q, float w, float e, float r, float t){
            float a = (r-e)-(q-w);
            float s = (q-w)-a;
            float d = e-q;
            return w + t*(w + t*(s + t*q));
        }
        float coserpolate(float e, float r, float t){
            float tmp = (1.f-cos(t*PI))/2.f;
            return r*tmp + (1-tmp)*e;
        }

        float tx1 = coserpolate(get(loX, loY), get(loX+1, loY), dX);
        float tx2 = coserpolate(get(loX, loY+1), get(loX+1, loY+1), dX);
        return coserpolate(tx1, tx2, dY);
    }

    float foo(float x, float y){
        float ret = 0.f;
        float amp = 0.8f;
        float freq = 0.025f;
        foreach(i ; 0 .. 3){
            ret += get(x, y, freq) * amp;
            freq *= 3.f;
            amp /= 3.f;
        }
        return ret*25.f;
    }

    Tile getTile(TilePos pos) {
        auto top = foo(to!float(pos.value.X), to!float(pos.value.Y));
        auto Z = pos.value.Z;
        auto d = Z - top;

        Tile ret;

        auto groundType = Z > 11 ? mud : rock;
        auto airType = Z > 5 ? air : water;
        
        if (-0.5 <= d && d < 0) {
            ret = Tile(groundType, TileFlags.none, 0, 0);
        } else if (d < -0.5) {
            ret = Tile(groundType, TileFlags.none, 0, 0);
        } else {
            assert (d > 0);
            ret = Tile(airType, TileFlags.none, 0, 0);
        }
        if (-0.5 <= d && d < 0.5) {
            ret.pathable = true;
            //addAABB(pos.getAABB());
        }
        ret.valid = true;

        return ret;
    }
    int maxZ(const TileXYPos xypos) {
        auto z = foo(to!float(xypos.value.X), to!float(xypos.value.Y));
        z = max(z, 5.f);
        return to!int(z);
    }
}
  

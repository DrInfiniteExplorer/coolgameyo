
module worldgen.newgen;

import std.exception;
import std.math, std.conv, std.random, std.algorithm;
import std.c.process;
import std.stdio;
import std.typecons;


import graphics.texture;
import graphics.debugging;
import pos;
import random.random;
import tiletypemanager;
import util;
import world;
import worldgen.worldgen;


final class WorldGeneratorNew : WorldGenerator {
    TileTypeManager sys;

    ValueSource heightmap;
    //Uniform randoms -> stored in map -> coserpolate


    ushort air, mud, rock, water;
    
    void init(WorldGenParams params, TileTypeManager tileTypeManager) {
        sys = tileTypeManager;
        air = sys.idByName("air");
        mud = sys.idByName("mud");
        rock = sys.idByName("rock");
        water = sys.idByName("water");
        
        auto randSource = new RandSourceUniform(params.randomSeed);
        auto worldSize = params.worldSize;
        //heightmap = new GradientNoise2D!665(randSource);
        //heightmap = new GradientField(vec3d(0,0,1), vec3d(0,0,0));
        auto gradNoise = new GradientNoise2D!665(randSource);
        heightmap = new Peturber(
            new GradientField(vec3d(0,0,1), vec3d(0,0,0)),
            null,
            null,
            new Fractal!3(
                [gradNoise, gradNoise, gradNoise],
                [1/90.1, 1.0/10, 1.0/3],
                [15.0, 00, 0]
            ),
            vec3d(1, 1, 1));
        
        auto v = heightmap.getValue(10, 10, 2);
        
    }
    
    
    
    bool destroyed = false;
    ~this() {
        enforce(destroyed, "WorldGeneratorNew.destroy not called!");
    }
    
    void destroy() {
        //TODO: Implement later
        //destroyed = true;
    }

    Tile getTile(TilePos pos) {
        auto v = heightmap.getValue(pos.value.X, pos.value.Y, pos.value.Z);
        //writeln(pos, v);
        Tile ret;

        auto groundType = mud;
        auto airType =  air;
        
        if (v > 0) { //Solid
            ret = Tile(groundType, TileFlags.none, 0, 0);
        } else {
            ret = Tile(airType, TileFlags.none, 0, 0);
            if (heightmap.getValue(pos.value.X, pos.value.Y, pos.value.Z-1) > 0) {
                ret.pathable = true;
            }
        }
        
        

        /*
        if (-0.5 <= d && d < 0.5) {
            ret.pathable = true;
            //addAABB(pos.getAABB());
        }
        */
        ret.valid = true;

        return ret;
    }
    int maxZ(const TileXYPos xypos) {
        //auto v = foo(xypos.value.X, xypos.value.Y);
        //auto vv = to!int(v);
        //return vv;
        return 16;
    }
}





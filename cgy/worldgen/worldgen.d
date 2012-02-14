module worldgen.worldgen;

import std.algorithm;
import std.c.process;
import std.conv;
//import std.file;
import std.math;
import std.random;
import std.stdio;

import json;

import light;

import tiletypemanager;
import world.world;

import pos;
import graphics.texture;
import graphics.debugging;
import random.random;
import random.randsource;
import random.gradientnoise;
import random.catmullrom;
import random.fractal;
import random.valuemap;
import random.modmultadd;
import random.modscaleoffset;
import random.xinterpolate;
import random.xinterpolate4;
import random.gradient;
import util.util;
import util.filesystem;

struct WorldGenParams {
    uint randomSeed = 880128;
    uint worldDiameter = 16; //Measures diameter of world, in number of sectors.

    double worldMin = -50;
    double worldMax = 450;

    uint heightmapSamplesInWorld() const @property {
        return worldDiameter * SectorSize.x / HeightMapSampleDistance;
    }
    
}

final class WorldGenerator {
    TileTypeManager sys;
    WorldGenParams params;

    ValueMap2D!double worldHeightMapImg;
    ValueSource worldHeightMap;
    ValueSource wierdnessMap;
    ValueSource temperatureMap;
    ValueSource humidityMap; //Water outflux
    ValueSource vegetationMap; //Water outflux
    
    void destroy() {
    }
    
    void serialize() {
        auto folder = "saves/current/worldgen";
        util.filesystem.mkdir(folder);
        worldHeightMapImg.saveBin(folder ~ "/heightmap.bin");
        auto jsonRoot = encode(params);
        std.file.write(folder ~ "/params.json", prettifyJSON(jsonRoot));



        /*
        double[4] colorize(double t) {
            auto c = [
                vec3d(0.0, 0.0, 1.0),
                vec3d(0.0, 0.0, 1.0),
                vec3d(0.0, 0.5, 0.5),
                vec3d(0.0, 1.0, 0.0),
                vec3d(0.5, 0.5, 0.0),
                vec3d(1.0, 0.0, 0.0),
                vec3d(1.0, 0.0, 0.0),
            ];
            auto v = CatmullRomSpline(t, c);
            return [v.X, v.Y, v.Z, 0];
        }

        auto img = worldHeightMapImg.toImage(params.worldMin, params.worldMax, true, &colorize);
        img.save("saves/current/worldgen/height.bmp");
        */


    }
    void deserialize() {
        auto folder = "saves/current/worldgen";
        auto content = readText(folder ~ "/params.json");
        json.read(params, content);

        worldHeightMapImg = new ValueMap2D!double;
        worldHeightMapImg.alloc(params.heightmapSamplesInWorld, params.heightmapSamplesInWorld);
        worldHeightMapImg.loadBin(folder ~ "/heightmap.bin");
    }

    void init(WorldGenParams params, TileTypeManager tileTypeManager) {
        this.params = params;
        sys = tileTypeManager;
        auto randSource = new RandSourceUniform(params.randomSeed);

        worldHeightMap = new OffsetGradientNoise!()(params.heightmapSamplesInWorld, randSource);   // [-500, 1500]
        auto fractalHeightMap = new HybridMultiFractal(worldHeightMap, 0.25, 2, 8, 0.6);

        fractalHeightMap.setBaseWavelength(1_000/HeightMapSampleDistance); // Hur många samples mellan varje "ursample". Storlek i sample mätt på grövsta formationerna.
        //worldHeightMap = fractalHeightMap;
        worldHeightMapImg = new ValueMap2D!double;
        writeln("Filling worldheightmap...");
        worldHeightMapImg.fill(fractalHeightMap, params.heightmapSamplesInWorld, params.heightmapSamplesInWorld); //Sampla ett värde per block
        writeln("...done!");
        worldHeightMapImg.normalize(params.worldMin, params.worldMax);
        auto interpolated = new BicubeInterpolation(worldHeightMapImg);
        //auto interpolated = worldHeightMap;
        //auto interpolated = worldHeightMapImg;
        double scale = 1.0 / HeightMapSampleDistance;
        worldHeightMap = new ModScaleOffset(interpolated, vec3d(scale), vec3d(params.heightmapSamplesInWorld/2 + 0.5, params.heightmapSamplesInWorld/2 + 0.5, 0));
        auto conicalGradient = new ConicalGradientField(vec3d(0, 0, -1), vec3d(0, 0, params.worldMax), (params.worldMax-params.worldMin)/(0.5*params.worldDiameter*SectorSize.x));
        //worldHeightMap = new AddSources(worldHeightMap, conicalGradient);
        //worldHeightMap = conicalGradient;
    }

    bool isInsideWorld(TilePos pos) {
        return pos.value.X ^^ 2 + pos.value.Y ^^ 2 < (SectorSize.x * params.worldDiameter*0.5)^^ 2;
    }
    
    double getHeight(TilePos pos) {
        return isInsideWorld(pos) ? worldHeightMap.getValue(pos.value.X, pos.value.Y)
            : params.worldMin;
    }
    double getHeight01(TilePos pos) {
        return (getHeight(pos) - params.worldMin) / (params.worldMax-params.worldMin);
    }
    double getWierdness(TilePos pos) {
        return isInsideWorld(pos) ? wierdnessMap.getValue(pos.value.X, pos.value.Y)
            : 0;
    }
    double getTemperature(TilePos pos) {
        return isInsideWorld(pos) ? temperatureMap.getValue(pos.value.X, pos.value.Y)
            : 0;
    }
    double getHumidity(TilePos pos) {
        return isInsideWorld(pos) ? humidityMap.getValue(pos.value.X, pos.value.Y)
            : 0;

    }
    double getVegetation(TilePos pos) {
        return isInsideWorld(pos) ? vegetationMap.getValue(pos.value.X, pos.value.Y)
            : 0;
    }
    double getVegetation01(TilePos pos) {
        return getVegetation(pos);
    }

    Tile getTile(TilePos pos) {
        if(! isInsideWorld(pos)) {
            return Tile(TileTypeAir, TileFlags.valid);
        }
        if(pos.value.Z >= maxZ(TileXYPos(pos))) {
            auto tile = Tile(TileTypeAir, TileFlags.valid);
            tile.sunLightValue = MaxLightStrength;
            return tile;
        }
        double height = getHeight(pos);
        double distAboveGround = pos.value.Z - height;
        if (distAboveGround > 0) {
            //Air
            return Tile(TileTypeAir, TileFlags.valid);
        }
        else {
            //Ground
            ushort type;
            if ( distAboveGround < -4) {
                type = sys.idByName("stone");
            } else {
                //auto snowHeight = params.worldMin + (params.worldMax-params.worldMin)*0.8;
                auto snowHeight = 300;
                if(pos.value.Z > snowHeight) {
                    type = sys.idByName("snow");
                } else {
                    type = sys.idByName("dirt");
                }
            }

            return Tile(type, TileFlags.valid);
        }
    }
    
    int maxZ(const TileXYPos xypos) {

        return cast(int) std.math.ceil(getHeight(xypos.toTilePos(0)));
    }
}
  

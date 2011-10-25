module worldgen.worldgen;

import std.math, std.conv, std.random, std.algorithm;
import std.c.process;
import std.stdio;

import tiletypemanager;
import world;

import pos;
import graphics.texture;
import graphics.debugging;
import random.random;
import random.randsource;
import random.gradientnoise;
import random.fractal;
import random.valuemap;
import random.modmultadd;
import random.modscaleoffset;
import random.xinterpolate;
import random.xinterpolate4;
import random.gradient;
import util.util;

struct WorldGenParams {
    uint randomSeed = 880128;
    uint worldSize = 8; //Measures diameter of world, in number of sectors.

    double worldMin = -50;
    double worldMax = 200;
    
}

final class WorldGenerator {
    TileTypeManager sys;
    WorldGenParams params;

    ValueSource worldHeightMap;
    ValueSource wierdnessMap;
    ValueSource temperatureMap;
    ValueSource humidityMap; //Water outflux
    ValueSource vegetationMap; //Water outflux
    
    void serialize(){}
    void deserialize(){}

    void destroy() {
    }
    
    void init(WorldGenParams params, TileTypeManager tileTypeManager) {
        this.params = params;
        sys = tileTypeManager;
        auto randSource = new RandSourceUniform(params.randomSeed);

        worldHeightMap = new OffsetGradientNoise!()(params.worldSize*BlocksPerSector.x, randSource);   // [-500, 1500]
        auto ridgedHeightMap = new RidgedMultiFractal(worldHeightMap, 0.75, 2, 1, 0.75, 1.5);
        ridgedHeightMap.setBaseWavelength(45); // Hur många block mellan varje "ursample". Storlek i block mätt på grövsta formationerna.
        //worldHeightMap = ridgedHeightMap;
        auto tmp = new ValueMap2D!double;
        tmp.fill(ridgedHeightMap, params.worldSize*BlocksPerSector.x, params.worldSize * BlocksPerSector.x); //Sampla ett värde per block
        tmp.normalize(params.worldMin, params.worldMax);
        auto interpolated = new BicubeInterpolation(tmp);
        //auto interpolated = worldHeightMap;
        //auto interpolated = tmp;
        double scale = 1.0 / BlocksPerSector.x;
        worldHeightMap = new ModScaleOffset(interpolated, vec3d(scale), vec3d(params.worldSize*BlocksPerSector.x/2 + 0.5, params.worldSize*BlocksPerSector.x/2 + 0.5, 0));
        auto conicalGradient = new ConicalGradientField(vec3d(0, 0, -1), vec3d(0, 0, params.worldMax), (params.worldMax-params.worldMin)/(0.5*params.worldSize*SectorSize.x));
        worldHeightMap = new AddSources(worldHeightMap, conicalGradient);


/*
        wierdnessMap = new GradientNoise01!()(params.worldSize, randSource);     // [0, 1]
        temperatureMap = new GradientNoise01!()(params.worldSize, randSource);   // [-20, 50]
        temperatureMap = new ModMultAdd!(70, -20)(temperatureMap);
        humidityMap = new GradientNoise01!()(params.worldSize, randSource);      // [0, 100]
        humidityMap = new ModMultAdd!(100, 0)(humidityMap);
*/
        /*
        static double derp(double t) {
            return t^^2;
        }
        //auto asd = new Filter!(derp)(vegetationMap);
        ValueSource asd = new MultMultMult(vegetationMap, new ModScaleOffset(vegetationMap, vec3d(1,1,1), vec3d(10000, -2313, 873927)));
        asd = new Filter!(derp)(asd);
        vegetationMap = new Fractal!4(
                [asd, vegetationMap, vegetationMap, vegetationMap],
                [80_000, 14533.0, 167.187345, 59.1123142],
                [130.0, 30, 25.0, 15.0]
            );
        */
        
        //vegetationMap = new GradientNoise!()(params.worldSize, randSource);    // [0, 100]
        
        //tmp.fill(vegetationMap, params.worldSize, params.worldSize, 0, 0, params.worldSize*SectorSize.x, params.worldSize * SectorSize.y);
        //vegetationMap = new BicubeInterpolation(tmp);
        //vegetationMap = new CosInterpolation(tmp);
        //vegetationMap = new BicubeInterpolation(vegetationMap);
        //vegetationMap = tmp; //Uncomment this to see the 'raw' bitmap of vegetation :)
        //auto scale = to!double(params.worldSize) / (SectorSize.x * params.worldSize);
        //vegetationMap = new ModScaleOffset(vegetationMap, vec3d(scale), vec3d(params.worldSize/2, params.worldSize/2, 0));
    }
    
    double getHeight(TilePos pos) {
        return worldHeightMap.getValue(pos.value.X, pos.value.Y);
    }
    double getHeight01(TilePos pos) {
        return (getHeight(pos) - params.worldMin) / (params.worldMax-params.worldMin);
    }
    double getWierdness(TilePos pos) {
        return wierdnessMap.getValue(pos.value.X, pos.value.Y);
    }
    double getTemperature(TilePos pos) {
        return temperatureMap.getValue(pos.value.X, pos.value.Y);
    }
    double getHumidity(TilePos pos) {
        return humidityMap.getValue(pos.value.X, pos.value.Y);
    }
    double getVegetation(TilePos pos) {
        return vegetationMap.getValue(pos.value.X, pos.value.Y);
    }
    double getVegetation01(TilePos pos) {
        return getVegetation(pos);
    }

    Tile getTile(TilePos pos) {
        double height = getHeight(pos);
        double distAboveGround = pos.value.Z - height;
        if (distAboveGround > 0) {
            //Air
            return Tile(TileTypeAir, TileFlags.valid, 0, 0);
        }
        else {
            //Ground
            return Tile(2, TileFlags.valid, 0, 0);
        }
    }
    
    int maxZ(const TileXYPos xypos) {

        return cast(int) std.math.ceil(getHeight(xypos.toTilePos(0)));
    }
}
  

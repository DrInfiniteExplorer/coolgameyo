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

struct WorldGenParams {
    uint randomSeed = 880128;
    uint worldSize = 8; //Measures diameter of world, in number of sectors.
    
}

final class WorldGenerator {
    TileTypeManager sys;
    WorldGenParams params;

    ValueSource worldHeightMap;
    ValueSource wierdnessMap;
    ValueSource temperatureMap;
    ValueSource rainfallMap; //Water influx
    ValueSource drainageMap; //Water outflux
    ValueSource vegetationMap; //Water outflux
    
    void serialize(){}
    void deserialize(){}

    void destroy() {
    }
    
    void init(WorldGenParams params, TileTypeManager tileTypeManager) {
        this.params = params;
        sys = tileTypeManager;
        auto randSource = new RandSourceUniform(params.randomSeed);

        worldHeightMap = new GradientNoise01!()(params.worldSize, randSource);   // [-500, 1500]
        worldHeightMap = new ModMultAdd!(2000, -500)(worldHeightMap);
        wierdnessMap = new GradientNoise01!()(params.worldSize, randSource);     // [0, 1]
        //wierdnessMap = new ModMultAdd!(0.5, 0.5)(wierdnessMap);
        temperatureMap = new GradientNoise01!()(params.worldSize, randSource);   // [-20, 50]
        temperatureMap = new ModMultAdd!(70, -20)(temperatureMap);
        rainfallMap = new GradientNoise01!()(params.worldSize, randSource);      // [0, 100]
        rainfallMap = new ModMultAdd!(100, 0)(rainfallMap);
        drainageMap = new GradientNoise01!()(params.worldSize, randSource);      // [0, 100]
        drainageMap = new ModMultAdd!(100, 00)(drainageMap);
        vegetationMap = new GradientNoise01!()(params.worldSize, randSource);    // [0, 100]
//        vegetationMap = new ModMultAdd!(100, 00)(vegetationMap);
        vegetationMap = new Fractal!3(
                [vegetationMap, vegetationMap, vegetationMap],
                [14533.0, 167.187345, 59.1123142],
                [50.0, 35.0, 15.0]
            );

    }
    
    
    
    double getHeight(TilePos pos) {
        return worldHeightMap.getValue(pos.value.X, pos.value.Y);
    }
    double getWierdness(TilePos pos) {
        return wierdnessMap.getValue(pos.value.X, pos.value.Y);
    }
    double getTemperature(TilePos pos) {
        return temperatureMap.getValue(pos.value.X, pos.value.Y);
    }
    double getRainfall(TilePos pos) {
        return rainfallMap.getValue(pos.value.X, pos.value.Y);
    }
    double getDrainage(TilePos pos) {
        return drainageMap.getValue(pos.value.X, pos.value.Y);
    }
    double getVegetation(TilePos pos) {
        return vegetationMap.getValue(pos.value.X, pos.value.Y);
    }
    double getVegetation01(TilePos pos) {
        return getVegetation(pos) / 100.0;
    }

    Tile getTile(TilePos pos) {        
        return Tile.init;
    }
    
    int maxZ(const TileXYPos xypos) {
        return int.init;
    }
}
  

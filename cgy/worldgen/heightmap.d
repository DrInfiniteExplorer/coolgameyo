module worldgen.heightmap;

import std.algorithm : swap;
import std.array : array;
import std.parallelism;
import std.mmfile;
import std.math;

import math.math : equals;
import math.math : advect, clamp, fastFloor;
import random.random : BSpline;
import random.xinterpolate4 : XInterpolate24;
import util.filesystem;
import util.pos;
import util.util;
import worldgen.maps;
import worldgen.strata;

enum sampleIntervall = 10; //10 meters between each sample

class HeightMaps {
    int worldSize; //In meters
    int mapSize; //In samples
    int mapSizeSQ;
    uint mapSizeBytes;
    WorldMap worldMap;

    MmFile heightmapFile;
    float[] mapData; // Pointer to memory in heightmapfile.
    MmFile soilFile;
    float[] soilData; // Pointer to memory in heightmapfile.

    this(WorldMap _worldMap) {
        worldMap = _worldMap;
        auto size = .worldSize; // 1 mil
        worldSize = size; // In meters woah.
        mapSize = worldSize / sampleIntervall;
        mapSizeSQ = mapSize ^^ 2;
        mapSizeBytes = mapSize * mapSize * float.sizeof;
        msg("mapSize(kilo)Bytes: ", mapSizeBytes / 1024);
    }

    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }
    void destroy() {
        destroyed = true;
        delete heightmapFile;
        delete soilFile;
        mapData = null;
        soilData = null;
    }

    void load() {
        auto heightPath = worldMap.worldPath ~ "/map1";
        msg("Loading heightmap at: ", heightPath);
        heightmapFile = new MmFile(heightPath, MmFile.Mode.readWrite, mapSizeBytes, null, 0);
        mapData = cast(float[])heightmapFile[];

        auto soilPath = worldMap.worldPath ~ "/map2";
        soilFile = new MmFile(soilPath, MmFile.Mode.readWrite, mapSizeBytes, null, 0);
        soilData = cast(float[])soilFile[];
    }

    void generate(int seed) {

        auto heightPath = worldMap.worldPath ~ "/map1";
        msg("Creating heightmap at: ", heightPath);
        BREAK_IF(heightmapFile !is null);
        heightmapFile = new MmFile(heightPath, MmFile.Mode.readWriteNew, mapSizeBytes, null, 0);
        mapData = cast(float[])heightmapFile[];

        auto soilPath = worldMap.worldPath ~ "/map2";
        soilFile = new MmFile(soilPath, MmFile.Mode.readWrite, mapSizeBytes, null, 0);
        soilData = cast(float[])soilFile[];

        auto startTime = utime();

        float maxHeight = 10_000;
        float startAmplitude = maxHeight / 2;

        /*
        float endAmplitude = 0.5;
        int octaves = cast(int)logb(startAmplitude / endAmplitude);
        

        float endIntervall = 3;
        float startIntervall = endIntervall * 2^^octaves;
        */

        float startIntervall = 6000;
        float endIntervall = sampleIntervall;
        int octaves = cast(int)logb(startIntervall / endIntervall);
        float endAmplitude = startAmplitude * (0.5 ^^ octaves);

        float baseFrequency = 1.0f / startIntervall;


        msg("Octaves: ", octaves);
        msg("Start amplitude: ", startAmplitude);
        msg("Start intervall: ", 1.0f / baseFrequency, " | ", startIntervall);
        msg("End amplitude: ", startAmplitude * 0.5^^octaves, " | ", endAmplitude);
        msg("End intervall: ", 0.5^^octaves / baseFrequency, " | ", endIntervall);

        import random.simplex;
        auto noise = new SimplexNoise(seed);

        uint LIMIT = mapSize * mapSize;
        uint LIMIT_STEP = LIMIT / 2500;
        //for(uint i = 0; i < LIMIT; i++) {
        uint progress = 0;
        foreach(uint i, ref value ; parallel(mapData)) {
            if( (i % LIMIT_STEP) == 0) {
                progress += LIMIT_STEP;
                msg("Progress: ", 100.0f * cast(float)progress / LIMIT);
            }

            float value = 0;
            auto pos = vec2f(i % mapSize, i / mapSize);
            pos *= baseFrequency;

            float amplitude = startAmplitude;

            for(int iter = 0; iter < octaves; iter++) {
                value += amplitude * noise.getValue2(pos.convert!double);
                amplitude *= 0.5;
                pos *= 2;
            }

            mapData[i] = value;
        }

        msg("Time to make heightmap: ", (utime() - startTime) / 1_000_000.0);


        foreach(uint i, ref value ; parallel(mapData)) {
            auto x = i % mapSize;
            auto y = i / mapSize;
            auto dst = vec2f(x,y).getDistance(vec2f(mapSize * 0.5));

            mapData[i] = dst < mapSize*0.25 ? 100 : 0;
        }



        applyErosion(seed);
    }


    int above(int idx) { return idx - mapSize; }
    int below(int idx) { return idx + mapSize; }
    int left (int idx) { return idx - 1; }
    int right(int idx) { return idx + 1; }

    void applyErosion(int seed) {
        /// HO HO HO :D
        float[] height = mapData.array;    // Read from during iteration, copy to from newHeight at end.
        float[] newHeight = mapData.array; //Updated during fluid ground stealing and talus-falling.
        float[] water;
        float[] sediment;
        float[] sedimentOut; // Out of advection that is.
        float[4][] waterFlow;
        float[] soil;
        float[] newSoil; // Write to yeah!
        vec2f[] velocity;

        water.length = mapSizeSQ;
        sediment.length = mapSizeSQ;
        sedimentOut.length = mapSizeSQ;
        waterFlow.length = mapSizeSQ;
        soil.length = mapSizeSQ;
        newSoil.length = mapSizeSQ;

        velocity.length = mapSizeSQ;

        water[] = 0.0;
        sediment[] = 0.0; // 3 meters of sediment-isch stuff.
        waterFlow[] = [0, 0, 0, 0];
        soil[] = 3.0; // Start with 3 meters of soil

        int dirToIdx(int idx, int dir) {
            switch(dir) {
                case 0: return right(idx);
                case 1: return above(idx);
                case 2: return left(idx);
                case 3: return below(idx);
                default: BREAKPOINT;
            }
            assert(0);
        }
        bool border(int idx, int dir) {
            if( ((idx+1) % mapSize) == 0 && dir == 0) return true;
            if( (idx / mapSize) == 0 && dir == 1) return true;
            if( (idx % mapSize) == 0 && dir == 2) return true;
            if( ((idx+mapSize) / mapSize) == mapSize && dir == 3) return true;
            return false; //TODO: Unittest these etc yeah! :D
        }
        float waterHeightDiff(int idx, int dir) { //How much higher is our water than @dir ?
            int idx2 = dirToIdx(idx, dir);
            return height[idx] + soil[idx] + water[idx] - height[idx2] - soil[idx2] - water[idx2];
        }
        float pressure;
        float force;
        float acceleration;
        float mass;
        immutable cellLength = 1.0;
        immutable cellArea = cellLength ^^ 2;
        immutable pipeArea = 1.0;
        immutable pipeLength = cellLength; // Huerr dunno.
        immutable fluidDensity = 1000.0;
        immutable gravity = 9.8;
        immutable deltaTime = 1.0;

        immutable minSlopeConstant = 0.2;

        immutable capacityConstant = 0.5;

        immutable depositionConstant = 0.5;
        immutable soilDissolutionConstant = 0.5;

        immutable evaporationConstant = 0.15; // 15% of water will evaporate hurr durr.
        immutable rainWaterAmount = 0.125; // It will rain on 12,5% of the world all the time. Uhr..
        immutable randomWaterCount = mapSizeSQ * rainWaterAmount;
        immutable rainFallConstant = 1.0; // Will randomly fall 1 ton of water on shit.
        import std.random;
        Random r;
        r.seed(seed);

        foreach(iteration ; 0 .. 5000) {
            msg("Erosion! Iteration ", iteration);

            // Add random water
            // Maybe need more random water.
            foreach(i ; 0 .. randomWaterCount) {
                int idx = uniform(0, mapSizeSQ-1, r);
                water[idx] += rainFallConstant;
            }

            //Update flows
            import std.range : iota;
            foreach(idx ; parallel(iota(0, mapSizeSQ))) {
                float[4] flows; // Out-flows. Flow * time = volume.
                float flowSum = 0;
                foreach(dir ; 0 .. 4) {
                    if(border(idx, dir)) {
                        flows[dir] = 0;
                        continue;
                    }
                    pressure = fluidDensity * gravity * waterHeightDiff(idx, dir);
                    force = pressure * pipeArea;
                    mass = fluidDensity * pipeLength;
                    acceleration = force / mass;

                    float flow = max(0, waterFlow[idx][dir] + deltaTime * pipeArea * acceleration);
                    flows[dir] = flow;
                    flowSum += flow;
                }
                //msg("fs:", flowSum);
                float availableWater = cellArea * water[idx];
                float flowVolumeSum = flowSum * deltaTime; // flow * time = volume. like amps * time = charge.
                if(flowVolumeSum > availableWater) { //More water running out than available water. Normalize.
                    flows[] *= availableWater / flowVolumeSum;
                    flowVolumeSum = availableWater;
                }
                //BREAK_IF(flowVolumeSum > 0); // Huerr until further notice there IS no water in the systems at all!! :S
                //msg(idx, ":", flowVolumeSum);
                waterFlow[idx] = flows;
            }
            //Does not preserve volume. See Stava 2008, Mei 2007+, OBrien 95

            //Add water running into the cell.
            //Then compute velocity in cell as well since all prerequicites are met (all flows)
            //Might as well deposit / erode some sediment during this phase, yeah.
            //foreach(idx; parallel(iota(0, mapSizeSQ))) {
            foreach(idx; iota(0, mapSizeSQ)) {
                    // Can here use average of volume out sum and previous volume out sum
                //   See page 8 of Mei 2007+
                // In case of that also do that
                
                int leftIdx = left(idx);
                int rightIdx = right(idx);
                int belowIdx = below(idx);
                int aboveIdx = above(idx);
                bool leftBorder = border(idx, 2);
                bool rightBorder = border(idx, 0);
                bool aboveBorder = border(idx, 1);
                bool belowBorder = border(idx, 3);

                float startWaterHeight = water[idx];
                float[4] flows = waterFlow[idx];
                float flowDiff = 0; // Positive flow is incomming water
                flowDiff -= flows[0];
                flowDiff -= flows[1];
                flowDiff -= flows[2];
                flowDiff -= flows[3];
                BREAK_IF(flowDiff > 0); // Out-flow cant be negative..
                float flowFromRight = 0, flowFromAbove = 0, flowFromLeft = 0, flowFromBelow = 0;
                if(!rightBorder) {
                    flowFromRight = waterFlow[rightIdx][2];
                    flowDiff += flowFromRight;
                }
                if(!aboveBorder) {
                    flowFromAbove = waterFlow[aboveIdx][3];
                    flowDiff += flowFromAbove;
                }
                if(!leftBorder) {
                    flowFromLeft = waterFlow[leftIdx][0];
                    flowDiff += flowFromLeft;
                }
                if(!belowBorder) {
                    flowFromBelow = waterFlow[belowIdx][1];
                    flowDiff += flowFromBelow;
                }
                float flowVolume = flowDiff * deltaTime;
                float endWaterHeight = startWaterHeight + flowVolume / cellArea;
                if(endWaterHeight < 0) {
                    //BREAK_IF(!equals(endWaterHeight, 0));
                    endWaterHeight = 0;
                }
                water[idx] = endWaterHeight;
                // velo city!
                float averageWaterHeight = 0.5 * ( startWaterHeight + endWaterHeight);
                float flowToRight = 0.5 * (flowFromLeft + flows[0] - flows[2] - flowFromRight );
                float flowToDown =  0.5 * (flowFromAbove + flows[3] - flows[1] - flowFromBelow );
                //since flow = cellLength * averageWaterHeight * velocity
                // Hoho! Error in description in Stava 2008 p 205 (5).
                // By reading Mei 2007+ one can understand what is supposed to happen when
                // calculating velocity. (regarding averageWaterHeight)
                float velocityToRight = averageWaterHeight ? flowToRight / (cellLength * averageWaterHeight) : 0;
                float velocityToDown = averageWaterHeight ? flowToDown / (cellLength * averageWaterHeight) : 0;
                auto vel = vec2f(velocityToRight, velocityToDown);
                velocity[idx] = vel;
                //msg(vel.getLength);

                float slopeX, slopeY;
                //For the time being use a simple kind of slope calculation.
                int rightSlopeIdx = rightBorder ? idx : rightIdx;
                int  leftSlopeIdx =  leftBorder ? idx : leftIdx;
                int aboveSlopeIdx = aboveBorder ? idx : aboveIdx;
                int belowSlopeIdx = belowBorder ? idx : belowIdx;
                slopeX = height[leftSlopeIdx] + soil[leftSlopeIdx] - height[rightSlopeIdx] - soil[rightSlopeIdx];
                slopeY = height[aboveSlopeIdx] + soil[aboveSlopeIdx] - height[belowSlopeIdx] - soil[belowSlopeIdx];
                slopeX *= 0.5 / cellLength;
                slopeY *= 0.5 / cellLength;

                // capacity = |v| * sin(slopeAngle) * constant
                // since sin(slopeangle) is the normalized slope(LIES*), and the actual slopeangle
                // to consider ought to be the one in which the fluid moves, it makes sense
                // to regard it as capacity = |v| * dot( norm(v), [slopeX, slopeY])
                // which is dot(v, [slopeX, slopeY].
                //It makes no sense that the capacity should increase when going up slopes,
                // but we can probably assume that the water will do this excessively seldom
                // and can 'safely' disregard that case.
                //
                // * = sin(x) = √(dx²+dy²) / dy
                //FIXMELATER

                auto asd = vel;
                asd.normalize();

                // Why does this compile? :S
                vec2f slope = vec2f(slopeX, slopeY).dotProduct(asd);

                float minSlope = max(minSlopeConstant, slope.getLength);
                float sedimentCapacity = vel.getLength() * capacityConstant * minSlope;
                //msg("sed ", sedimentCapacity);


                int x = idx % mapSize;
                int y = idx / mapSize;
                int z = fastFloor(height[idx] - mapData[idx]); // Depth under 'normal' generated world
                BREAK_IF(z > 0);
                int materialNum = worldMap.getStrataNum(x, y, z);
                auto material = worldMap.materials[materialNum];

                float soilLevel = soil[idx];
                float carriedSediment = sediment[idx];
                float sedimentExcess = carriedSediment - sedimentCapacity; // if can carry 5 but has 6 then is 1
                if(sedimentExcess >= 0) {
                    //Deposit percentage of excess
                    float toDeposit = depositionConstant * sedimentExcess;
                    newSoil[idx] = soilLevel + toDeposit;
                    sediment[idx] -= toDeposit;
                } else {
                    float stuffToAbsorb = -sedimentExcess; // -sedímentExcess = how much more we can carry
                    float soilToAbsorb = soilDissolutionConstant * stuffToAbsorb;
                    float newSoilLevel = max(0, soilLevel - soilToAbsorb);
                    newSoil[idx] = newSoilLevel;
                    float soilAbsorbed = soilLevel - newSoilLevel;
                    carriedSediment += soilAbsorbed;

                    stuffToAbsorb -= soilAbsorbed;
                    if(stuffToAbsorb > 0) {
                        float materialDissolutionConstant = material.dissolutionConstant;
                        float materialToAbsorb = materialDissolutionConstant * stuffToAbsorb;
                        carriedSediment += materialToAbsorb;
                        newHeight[idx] -= materialToAbsorb;
                    }
                    sediment[idx] = carriedSediment;
                }
            }
            //We now have running water. Yay.
            height[] = newHeight[]; // Copy newly computed (and partially old) values to height.
            swap(soil, newSoil);

            //Advect (move) sediment
            float getSediment(vec2f pos) {
                int x = cast(int)clamp(pos.x, 0, mapSize-1);
                int y = cast(int)clamp(pos.y, 0, mapSize-1);
                int idx = y * mapSize + x;
                return sediment[idx];
            }
            void setSediment(int x, int y, float value) {
                int idx = y * mapSize + x;
                sedimentOut[idx] = value;
            }
            vec2f getVelocity(int x, int y) {
                if(x < 0 || y < 0 || x >= mapSize || y >= mapSize) return vec2f(0);
                int idx = y * mapSize + x;
                return velocity[idx];
            }

            import random.xinterpolate : XInterpolate2;
            import random.random : lerp;
            //import util.traits : tryCall;
            alias XInterpolate2!(lerp, getVelocity, vec2f) getVel;

            auto derp(vec2f pt){ return getVel(pt - vec2f(0.5));}
            //alias XInterpolate2!(lerp, getSediment, vec2f) getSed;
            alias XInterpolate2!(lerp, getSediment, vec2f) getSed;

            //advect(&getVel, &getSed, &setSediment, mapSize, mapSize, deltaTime);
            advect(&derp, &getSed, &setSediment, mapSize, mapSize, deltaTime);

            // EVAPORATE WATER YEAH
            water[] *= (1-evaporationConstant * deltaTime);

            if((iteration % 5) == 0) {

                // Do some shifting of stuff, where angles are too steep.
                import std.conv : to;
                float[] derp = mapData[].array;
                derp[] -= height[];
                import std.algorithm;
                auto pred = map!abs(derp); 
                auto ma = reduce!(max)(pred);
                msg("max diff: ", ma);
                ma = reduce!(max)(map!"a.getLength()"(velocity));
                msg("max velocity: ", ma);
                msg("max water: ", reduce!max(water));
                msg("min water: ", reduce!min(water));
                msg("avg water: ", reduce!"a+b"(water) / mapSizeSQ);
                msg("max carried: ", reduce!max(sediment));
                msg("min carried: ", reduce!min(sediment));
                msg("avg carried: ", reduce!"a+b"(sediment) / mapSizeSQ);
            }

        }
        mapData[] = height[];
        soilData[] = soil[];





    }

    ref float getMapValue(string which)(int x, int y) {
        BREAK_IF(x < 0);
        BREAK_IF(y < 0);
        BREAK_IF(x >= mapSize);
        BREAK_IF(y >= mapSize);
        auto idx = y * mapSize + x;
        return mixin(which)[idx];
    }

    alias getMapValue!"mapData" getHeightValue;
    alias getMapValue!"soilData" getSoilValue;

    float getMap(string which, bool interpolate = true)(TileXYPos pos) {
        vec2f pt = pos.value.convert!float / cast(float)sampleIntervall;
        auto get = &getMapValue!which;
        static if(interpolate) {
            return XInterpolate24!(BSpline, get)(pt);
        } else {
            return get(cast(int)pt.x, cast(int)pt.y);
        }
    }

    auto getHeight(bool interpolate = true)(TileXYPos pt) {
        return getMap!("mapData", interpolate)(pt);
    }
    auto getSoil(bool interpolate = true)(TileXYPos pt) {
        return getMap!("soilData", interpolate)(pt);
    }

    /*
    ref float getHeightValue(int x, int y) {
    }

    float getHeight(bool interpolate = true)(TileXYPos pos) {
        vec2f pt = pos.value.convert!float / cast(float)sampleIntervall;
        auto get = &getHeightValue;
        static if(interpolate) {
            return XInterpolate24!(BSpline, get)(pt);
        } else {
            return get(cast(int)pt.x, cast(int)pt.y);
        }
    }
    */
}


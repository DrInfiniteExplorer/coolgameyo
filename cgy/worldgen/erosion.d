
module worldgen.erosion;

import std.algorithm : abs, max, min, reduce, swap;
import std.array : array;
import std.typecons : Tuple;
import std.range : iota;
import std.random;

import graphics.heightmap;
import math.math : advect, clamp, equals, fastFloor, fastCeil;
import math.vector;
import random.random : lerp;
import random.xinterpolate : XInterpolate2;
import util.util : BREAK_IF, msg;

immutable cellLength = 10.0;
immutable cellArea = cellLength ^^ 2;
immutable pipeArea = 0.5;
immutable pipeLength = cellLength; // Huerr dunno.
immutable gravity = 9.8;

immutable deltaTime = 0.1;

immutable minSlopeConstant = 0.2;

immutable capacityConstant = 0.05;

immutable depositionConstant = 0.1;
immutable soilDissolutionConstant = 0.05;

immutable evaporationConstant = 0.05; //  5% of water will evaporate hurr durr.

immutable SoilTalus = 1.5;

immutable rainWaterAmount = 0.125; // It will rain on 12,5% of the world all the time. Uhr..
//immutable randomWaterCount = mapSizeSQ * rainWaterAmount;
immutable rainFallConstant = 1.0; // Will randomly fall 1 ton of water on shit.



class Erosion {
    int seed = void;
    int sizeX = void;
    int sizeY = void;
    int sizeSQ = void;
    const(float)[] sourceHeight;

    alias Tuple!(float, float) delegate(int x, int y, int z) GetMaterialConstants;
    GetMaterialConstants getMaterialConstants;

    float[] height;
    float[] soil;
    float[] water;
    float[] sediment;
    float[4][] waterFlow;
    vec2f[] velocity;

    float[] newHeight;
    float[] newSoil;
    float[] newSediment;

    Random r;


    Heightmap heightMap;

    int above(int idx) { return idx - sizeX; }
    int below(int idx) { return idx + sizeX; }
    int left (int idx) { return idx - 1; }
    int right(int idx) { return idx + 1; }
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
        if( ((idx+1) % sizeX) == 0 && dir == 0) return true;
        if( (idx / sizeY) == 0 && dir == 1) return true;
        if( (idx % sizeX) == 0 && dir == 2) return true;
        if( ((idx+sizeX) / sizeX) == sizeY && dir == 3) return true;
        return false; //TODO: Unittest these etc yeah! :D
    }


    void init(float[] startHeightmap, float[] startSoilmap, GetMaterialConstants _gmc, int _sizeX, int _sizeY, int _seed) {
        seed = _seed;
        r.seed(seed);
        sizeX = _sizeX;
        sizeY = _sizeY;
        sizeSQ = sizeX * sizeY;
        getMaterialConstants = _gmc;
        sourceHeight = startHeightmap;
        height = startHeightmap.array;
        soil = startSoilmap.array;

        water.length = sizeSQ;
        sediment.length = sizeSQ;
        waterFlow.length = sizeSQ;
        velocity.length = sizeSQ;

        newHeight.length = sizeSQ;
        newSoil.length = sizeSQ;
        newSediment.length = sizeSQ;

        water[] = 0.0;
        sediment[] = 0.0;
        waterFlow[] = [0, 0, 0, 0];
        
        //water[sizeSQ / 2 - sizeX / 2] += 33;
        //placeWater(sizeX / 2, sizeY / 2, 63, 20);

    }

    void placeWater(int X, int Y, float volume, float radius) {
        int R = fastCeil(radius);
        float sum = 0;
        foreach(x, y ; Range2D(X-R, X+R, Y-R, Y+R)) {
            if(x < 0 || y < 0 || x >= sizeX || y >= sizeY) continue;
            float dist = vec2f(x,y).getDistance(vec2f(X,Y));
            float height = max(0, radius - dist);
            sum += height;
        }   
        float norm = volume / sum;
        foreach(x, y ; Range2D(X-R, X+R, Y-R, Y+R)) {
            if(x < 0 || y < 0 || x >= sizeX || y >= sizeY) continue;
            float dist = vec2f(x,y).getDistance(vec2f(X,Y));
            float height = max(0, radius - dist);
            float waterAmount = height * norm;

            water[y * sizeX + x] += waterAmount;
        }   
    }
    
    float waterAmount = 1000;
    int iter;
    void erode() {
        // Add water to system.
        // void    ->    water
        //water[sizeSQ / 2 - sizeX / 2] += 3.3 * deltaTime;
        iter++;
        if(waterAmount > 0) {
            msg(iter, " adding");
            float amount = 3.3 * deltaTime;
            int randX = uniform(0, sizeX-1, r);
            int randY = uniform(0, sizeX-1, r);
            placeWater(randX, randY, amount, 5);
            waterAmount -= amount;
        } else {
            msg(iter);
        }

        //  water[0](global), height[0](global), soil[0](global)   ->    waterFlows[0]
        calculateFlows();

        // water[0](local), waterFlows[0](local) -> water[0]
        // averageWater(water[0]), waterFlows[0](global)   ->   velocity[0]
        // height[0](global), soil[0](global), velocity[0](local), sediment[0](local) -> height[1], soil[1], sediment[0]
        transportWaterVelocitySediment();
        //msg("vel ", reduce!"a+b"(map!"a.getLength"(velocity))/sizeSQ);

        // sediment[0](global), velocity[0](global) -> sediment[1]
        transportSediment();
        // water[0](local) -> water[0]
        evaporate();

        // height[1](global), soil[1](global) -> height[0](global), soil[0](global)
        talus();

        // Move data around so that stuff is ready for next erode
        // sediment[1] -> sediment[0];
        swap(sediment, newSediment);

        vec3f[] colors;
        colors.length = sizeSQ;
        if(heightMap) {
            synchronized(heightMap) {
                heightMap.load(height);
                foreach(idx, ref color ; colors) {
                    vec3f col;
                    float s = clamp(soil[idx], 0, 1);
                    col = lerp(vec3f(0.4), vec3f(0, 0.6, 0), s);
                    float wat = water[idx] * 25;
                    float t = clamp(wat, 0, 1);
                    col = lerp(col, vec3f(0, 0, 0.6), t);
                    col.x = sediment[idx];
                    color = col;
                }
                heightMap.setColor(colors);
            }
        }
}

    //  water[0](global), height[0](global), soil[0](global)   ->    waterFlows[0]
    void calculateFlows() {
        float[4] flows; // Out-flows. Flow * time = volume.
        foreach(idx ; 0 .. sizeSQ) {
            int asd = 5;
            flows[] = waterFlow[idx];
            foreach(dir ; 0 .. 4) {
                if(border(idx, dir)) {
                    flows[dir] = 0;
                    continue;
                }
                int otherIdx = dirToIdx(idx, dir);
                auto waterHeightDiff = height[idx] - height[otherIdx] + soil[idx] - soil[otherIdx] + water[idx] - water[otherIdx];
                float derp = pipeArea * gravity * waterHeightDiff / pipeLength;

                flows[dir] = max(0, flows[dir] + deltaTime * derp);
            }
            float flowSum = reduce!"a+b"(flows);

            float availableWater = cellArea * water[idx];
            float flowVolumeSum = flowSum * deltaTime; // flow * time = volume. like amps * time = charge.
            if(flowVolumeSum > availableWater) { //More water running out than available water. Normalize.
                flows[] *= availableWater / flowVolumeSum;
                flowVolumeSum = availableWater;
            }
            waterFlow[idx] = flows;
        }
        //Does not preserve volume. See Stava 2008, Mei 2007+, OBrien 95
        // Does not concern us at the moment; exact physical simulation is not desired.
    }

    //Water:
    // water[0](local), waterFlows[0](local) -> water[0]
    //Velocity:
    // averageWater(water[0]), waterFlows[0](global)   ->   velocity[0]
    //Sediment:
    // height[0](global), soil[0](global), velocity[0](local), sediment[0](local) -> height[1], soil[1], sediment[0]
    void transportWaterVelocitySediment() {
        foreach(int idx; 0 .. sizeSQ) {
            //// BEGIN WATER ////
            // water[0](local), waterFlows[0](local) -> water[0]

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
            // Positive flow is outgoing water
            float flowDiff = -reduce!"a+b"(flows);
            BREAK_IF(flowDiff > 0); // Out-flow cant be negative.. And since we are removing outflows, the result must not be positive.. huerr :P
            if(flowDiff < 0) {
                //msg(idx, " ", flowDiff);
            }

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
            if(flowDiff > 0) {
                //msg("!", idx, " ", flowDiff);
            }
            float flowVolume = flowDiff * deltaTime;
            float endWaterHeight = startWaterHeight + flowVolume / cellArea;
            if(endWaterHeight < 0) {
                BREAK_IF(!equals(endWaterHeight, 0, 0.001f)); // Due to floating point we can have errors, just set to 0 then.
                endWaterHeight = 0;
            }
            water[idx] = endWaterHeight;
            // water[0](local), waterFlows[0](local) -> water[0]
            //// END WATER ////
            /*
            velocity[idx] = vec2f(0);
            swap(height, newHeight);
            swap(soil, newSoil);
            continue;
            */

            //// BEGIN VELOCITY ////
            // averageWater(water[0]), waterFlows[0](global)   ->   velocity[0]
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
            if(vel.getLength > 5) {
                //msg(vel.getLength(), "\t\t", averageWaterHeight, "\t", flowToRight);
            }
            // averageWater(water[0]), waterFlows[0](global)   ->   velocity[0]
            //// END VELOCITY ////

            //// BEGIN SEDIMENT ////
            // height[0](global), soil[0](global), velocity[0](local), sediment[0](local) -> height[1], soil[1], sediment[0]
            float slopeX, slopeY;
            //For the time being use a simple kind of slope calculation.
            int rightSlopeIdx = rightBorder ? idx : rightIdx;
            int  leftSlopeIdx =  leftBorder ? idx : leftIdx;
            int aboveSlopeIdx = aboveBorder ? idx : aboveIdx;
            int belowSlopeIdx = belowBorder ? idx : belowIdx;

            float myHeight = height[idx];

            vec2f heightDiff;
            vec2f velNorm = vel.normalized;
            int x_idx = velNorm.x > 0 ? rightSlopeIdx : leftSlopeIdx;
            int y_idx = velNorm.y > 0 ? belowSlopeIdx : aboveSlopeIdx;
            heightDiff.x = height[x_idx] - myHeight + soil[x_idx] - soil[idx];
            heightDiff.y = height[y_idx] - myHeight + soil[y_idx] - soil[idx];
            velNorm.x = abs(velNorm.x);
            velNorm.y = abs(velNorm.y);
            float heightDiffScalar = max(0, -heightDiff.dotProduct(velNorm));
            //ang = atan(minslope)
            //sin ang = heightDiff / dist; height = minSlope; dist = sqrt(pipeLength^^2 + slope^^2)
            float sinAng = heightDiffScalar / sqrt(pipeLength^^2 + heightDiffScalar^^2);
            float sedimentCapacity = vel.getLength() * capacityConstant * max(minSlopeConstant, sinAng);

            int x = idx % sizeX;
            int y = idx / sizeX;
            int z = fastFloor(myHeight - sourceHeight[idx]); // Depth under 'normal' generated world
            BREAK_IF(z > 0); // We shan't have added height. English? Real Proper English or just LIES?
            auto materialConstants = getMaterialConstants(x, y, z);
            float materialDissolutionConstant = materialConstants[0];

            float soilLevel = soil[idx];
            float carriedSediment = sediment[idx];
            float sedimentExcess = carriedSediment - sedimentCapacity; // if can carry 5 but has 6 then is 1

            float finalHeight, finalSediment, finalSoil;
            finalHeight = myHeight;
            finalSoil = soilLevel;
            finalSediment = carriedSediment;

            if(sedimentExcess >= 0) {
                //Deposit percentage of excess
                float toDeposit = depositionConstant * sedimentExcess;
                finalSediment = carriedSediment - toDeposit;
                finalSoil = soilLevel + toDeposit;
            } else {
                float stuffToAbsorb = -sedimentExcess; // -sedímentExcess = how much more we can carry
                float soilToAbsorb = soilDissolutionConstant * stuffToAbsorb;
                if(soilToAbsorb < soilLevel) {
                    carriedSediment += soilToAbsorb;
                    finalSoil = soilLevel - soilToAbsorb;
                } else {
                    carriedSediment += soilLevel;
                    stuffToAbsorb -= soilLevel;
                    finalSoil = 0;

                    float materialToAbsorb = materialDissolutionConstant * stuffToAbsorb;
                    materialToAbsorb = soilDissolutionConstant * stuffToAbsorb;
                    carriedSediment += materialToAbsorb;
                    finalHeight -= materialToAbsorb;
                }
                finalSediment = carriedSediment;
            }
            newHeight[idx] = finalHeight;
            sediment[idx] = finalSediment;
            newSoil[idx] = finalSoil;
            // height[0](global), soil[0](global), velocity[0](local), sediment[0](local) -> height[1], soil[1], sediment[0]
            //// END SEDIMENT ////
        }
    }




    float getSediment(vec2f pos) {
        int x = cast(int)clamp(pos.x, 0, sizeX-1);
        int y = cast(int)clamp(pos.y, 0, sizeY-1);
        int idx = y * sizeX + x;
        return sediment[idx];
    }
    void setSediment(int x, int y, float value) {
        int idx = y * sizeX + x;
        newSediment[idx] = value;
    }
    vec2f getVelocity(int x, int y) {
        if(x < 0 || y < 0 || x >= sizeX || y >= sizeY) return vec2f(0);
        int idx = y * sizeX + x;
        return velocity[idx];
    }

    // sediment[0](global), velocity[0](global) -> sediment[1]
    void transportSediment(){
        //Advect (move) sediment
        vec2f gv(int x, int y) { return getVelocity(x,y); }
        float gs(vec2f p) { return getSediment(p); }

        alias XInterpolate2!(lerp, gv, vec2f) getVelInterp;
        alias XInterpolate2!(lerp, gs, vec2f) getSedInterp;

        //msg(getVelInterp(vec2f(3,4)));

        //advect(&getVel, &getSed, &setSediment, mapSize, mapSize, deltaTime);
        advect(&getVelInterp, &getSediment, &setSediment, sizeX, sizeY, deltaTime);
    }

    // water[0](local) -> water[0]
    void evaporate() {
        water[] *= (1-evaporationConstant * deltaTime);
    }

    // height[1](global), soil[1](global) -> height[0](global), soil[0](global)
    void talus() {
        //Until further notice, just transport data to next iteration :P
        //return;


        swap(newHeight, height);
        swap(newSoil, soil);

        // To do it properly, one should probably iterate all the materials within the height difference
        // and talus-move them, but since only soil/nonsoil is handled it'd break stuff. Sortof.
        foreach(idx ; 0 .. sizeSQ) {
            float myHeight = height[idx];
            //Outward flow of material.
            int x = idx % sizeX;
            int y = idx / sizeX;
            int z = fastFloor(myHeight - sourceHeight[idx]); // Depth under 'normal' generated world
            BREAK_IF(z > 0); // We shan't have added height. English? Real Proper English or just LIES?
            auto materialConstants = getMaterialConstants(x, y, z);
            float materialTalus = materialConstants[1];
            float materialTalusLimit = materialTalus * cellLength;

            foreach(dir ; 0 .. 4) {
                if(border(idx, dir)) continue;
                int otherIdx = dirToIdx(idx, dir);
                float heightDiff = myHeight - newHeight[otherIdx];
                if(heightDiff > materialTalusLimit) {
                    float diff = deltaTime * (heightDiff - materialTalusLimit);
                    soil[otherIdx] += diff;
                    height[idx] -= diff;
                }
            }
        }
        float soilTalusLimit = SoilTalus * cellLength;

        foreach(idx ; 0 .. sizeSQ) {
            float mySoil = soil[idx];
            float myHeight = height[idx] + mySoil;
            float[4] outSoil;
            outSoil[] = 0;
            foreach(dir ; 0 .. 4) {
                if(border(idx, dir)) continue;
                int otherIdx = dirToIdx(idx, dir);
                float heightDiff = myHeight - height[otherIdx] - soil[otherIdx];
                if(heightDiff > soilTalusLimit) {
                    float diff = deltaTime * (heightDiff - soilTalusLimit);
                    outSoil[dir] = diff;
                }
            }
            float outSum = reduce!"a+b"(outSoil);
            if(outSum > mySoil) {
                outSoil[] *= mySoil/outSum;
                soil[idx] = 0;
            } else {
                soil[idx] -= outSum;
            }
            foreach(dir ; 0 .. 4) {
                if(border(idx, dir)) continue;
                int otherIdx = dirToIdx(idx, dir);
                soil[otherIdx] += outSoil[dir];
            }
            /*
            if(-diff > mySoil) {
                soil[idx] = 0;
            } else {
                soil[idx] = mySoil + diff;
            }
            */
        }
    }



}


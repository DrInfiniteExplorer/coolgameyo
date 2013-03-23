
module worldgen.gpuerosion;

import std.algorithm : swap, max, min, reduce;
import std.random;

import graphics.heightmap : Heightmap;
import graphics.ogl;
import graphics.shader;
import math.vector;
import math.math;
import statistics : MeasureTime, StupWatch;
import util.util : msg, BREAK_IF, BREAKPOINT;


immutable pipeArea = 20;
immutable gravity = 9.8;

immutable deltaTime = 0.02;
immutable rainRate = 0.012;
immutable evaporationConstant = 0.015; //  5% of water will evaporate hurr durr.

immutable waterDepthMax = 5.0;
immutable sedimentCapacity = 0.3;

immutable dissolutionConstant = 0.5;
immutable depositionConstant = 1.0;

immutable talusFlowMultiplier = 1.0;
import worldgen.maps : sampleIntervall;
immutable talusLimit = 1.0 * sampleIntervall;


immutable soilTalusConstant = 1.5;
immutable rockTalusConstant = 5.0;

class GPUErosion {
    int seed = void;
    size_t sizeX = void;
    size_t sizeY = void;
    size_t sizeSQ = void;
    const(float)[] sourceHeight;

    int workGroupsX;
    int workGroupsY;

    uint height;
    uint soil;
    uint water;
    uint sediment;
    uint waterFlow;
    uint velocity;
    uint talusMovement1;
    uint talusMovement2;

    uint newHeight;
    uint newSoil;
    uint newSediment;

    ShaderProgram!("size", "gravity", "deltaTime") flowShader;
    ShaderProgram!("pos", "radius", "norm") placeWaterShader;
    ShaderProgram!() waterShader;
    ShaderProgram!("size") velocityShader;
    ShaderProgram!("size", ) sedimentShader;
    ShaderProgram!("size", "deltaTime", ) transportSedimentShader;
    ShaderProgram!("size") talusShader;
    ShaderProgram!("size", "deltaTime", "talusLimit") flowTalusShader;
    ShaderProgram!("size", "deltaTime") moveTalusShader;
    ShaderProgram!("evaporationConstant") evaporateShader;

    Heightmap heightMap;
    Heightmap waterMap;
    Random r;

    void init(float[] startHeightmap, float[] startSoilmap, size_t _sizeX, size_t _sizeY, int _seed) {
        seed = _seed;
        r.seed(seed);
        sizeX = _sizeX;
        sizeY = _sizeY;
        sizeSQ = sizeX * sizeY;

        height = Create2DTexture!(GL_R32F, float)(sizeX, sizeY, startHeightmap.ptr);
        soil = Create2DTexture!(GL_R32F, float)(sizeX, sizeY, startSoilmap.ptr);

        water = Create2DTexture!(GL_R32F, float)(sizeX, sizeY, null);
        sediment = Create2DTexture!(GL_R32F, float)(sizeX, sizeY, null);
        waterFlow = Create2DTexture!(GL_RGBA32F, float)(sizeX, sizeY, null);
        velocity = Create2DTexture!(GL_RG32F, float)(sizeX, sizeY, null);

        newHeight = Create2DTexture!(GL_R32F, float)(sizeX, sizeY, null);
        newSoil = Create2DTexture!(GL_R32F, float)(sizeX, sizeY, null);
        newSediment = Create2DTexture!(GL_R32F, float)(sizeX, sizeY, null);

        talusMovement1 = Create2DTexture!(GL_RGBA32F, float)(sizeX, sizeY, null);
        talusMovement2 = Create2DTexture!(GL_RGBA32F, float)(sizeX, sizeY, null);

        FillTexture(water, 0, 0, 0, 0);
        FillTexture(sediment, 0, 0, 0, 0);
        FillTexture(waterFlow, 0, 0, 0, 0);

        immutable S_X = "10";
        immutable S_Y = "10";
        int groupSizeX = mixin(S_X);
        int groupSizeY = mixin(S_Y);
        BREAK_IF( (sizeX % groupSizeX) != 0);
        BREAK_IF( (sizeY % groupSizeY) != 0);
        workGroupsX = cast(int)sizeX / groupSizeX;
        workGroupsY = cast(int)sizeY / groupSizeY;

        string header = q{
            #version 430
            layout(local_size_x = } ~ S_X ~ q{ , local_size_y = } ~ S_Y ~ q{, local_size_z = 1) in;
        };

        placeWaterShader = new typeof(placeWaterShader);
        placeWaterShader.compileSource!(ShaderType.Compute)(header ~ placeWaterShaderSource);
        placeWaterShader.link();

        flowShader = new typeof(flowShader);
        flowShader.compileSource!(ShaderType.Compute)(header ~ flowShaderSource);
        flowShader.link();

        waterShader = new typeof(waterShader);
        waterShader.compileSource!(ShaderType.Compute)(header ~ waterShaderSource);
        waterShader.link();

        velocityShader = new typeof(velocityShader);
        velocityShader.compileSource!(ShaderType.Compute)(header ~ velocityShaderSource);
        velocityShader.link();

        sedimentShader = new typeof(sedimentShader);
        sedimentShader.compileSource!(ShaderType.Compute)(header ~ sedimentShaderSource);
        sedimentShader.link();

        transportSedimentShader = new typeof(transportSedimentShader);
        transportSedimentShader.compileSource!(ShaderType.Compute)(header ~ transportSedimentShaderSource);
        transportSedimentShader.link();

        flowTalusShader = new typeof(flowTalusShader);
        flowTalusShader.compileSource!(ShaderType.Compute)(header ~ flowTalusShaderSource);
        flowTalusShader.link();

        moveTalusShader = new typeof(moveTalusShader);
        moveTalusShader.compileSource!(ShaderType.Compute)(header ~ moveTalusShaderSource);
        moveTalusShader.link();

        evaporateShader = new typeof(evaporateShader);
        evaporateShader.compileSource!(ShaderType.Compute)(header ~ evaporateShaderSource);
        evaporateShader.link();
    }

    
    float waterAmount = 3000;
    int iter;
    void erode() {
        iter++;
        msg(iter);
        {

            mixin(MeasureTime!"Erosion: ");
            rain();
            calculateFlows();
            computeWater();
            computeVelocity();
            computeSediment(); //height, soil -> newHeight, newSoil.

            transportSediment(); //soil -> newSoil. uses soil & velocity only.
            swap(sediment, newSediment);

            //swap(height, newHeight);
            //swap(soil, newSoil);


            talusFlow();
            talusMove();
            evaporate();

        }
        {
            mixin(MeasureTime!"Ero Height");
            //vec3f[] colors;
            //colors.length = sizeSQ;
            float[] hm;
            float[] sl;
            if(heightMap) {
                /*
                hm.length = sizeSQ;
                sl.length = sizeSQ;
                glBindTexture(GL_TEXTURE_2D, height); glError();
                glGetTexImage(GL_TEXTURE_2D, 0, GL_RED, GL_FLOAT, hm.ptr);glError();
                glBindTexture(GL_TEXTURE_2D, soil); glError();
                glGetTexImage(GL_TEXTURE_2D, 0, GL_RED, GL_FLOAT, sl.ptr);glError();
                hm[] += sl[];
                //msg("h max", reduce!max(hm));
                //msg("h min", reduce!min(hm));
                */

                synchronized(heightMap) {
                    //heightMap.load(hm);
                    uint[2] tex;
                    tex[0] = height;
                    tex[1] = soil;
                    heightMap.loadTexture(tex, cast(int)sizeX, cast(int)sizeY);
                    heightMap.setColor(vec3f(0.4, 0.7, 0.3));
                }
            }
            if(waterMap) {

                synchronized(waterMap) {
                    uint[3] tex;
                    tex[0] = height;
                    tex[1] = soil;
                    tex[2] = water;
                    waterMap.loadTexture(tex, cast(int)sizeX, cast(int)sizeY);
                    waterMap.setColor(vec3f(0.0, 0.0, 0.4));
                }
            }
        }
    }

    void setConstants(T)(T prog) {
        prog.uniform.size = vec2i(cast(int)sizeX, cast(int)sizeY);
        prog.uniform.gravity = gravity;
        prog.uniform.deltaTime = deltaTime;

        prog.uniform.soilTalusConstant = soilTalusConstant;
        prog.uniform.rockTalusConstant = rockTalusConstant;
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
        placeWaterShader.use();
        placeWaterShader.uniform.uniformRain = false;
        placeWaterShader.uniform.pos = vec2i(X, Y);
        placeWaterShader.uniform.radius = radius;
        placeWaterShader.uniform.norm = norm;
        glBindImageTexture(0, water, 0, GL_FALSE, 0, GL_READ_WRITE, GL_R32F); glError();
        glDispatchCompute(workGroupsX, workGroupsY, 1); glError();
        glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
        placeWaterShader.use(false);
    }

    string placeWaterShaderSource = q{
        layout(binding=0, r32f) uniform image2D water; //readwrite
        uniform ivec2 pos;
        uniform float radius;
        uniform float norm;
        uniform bool uniformRain;
        uniform float rainAmount;

        void main() {
            ivec2 myPos = ivec2(gl_GlobalInvocationID.xy);
            float myWater = imageLoad(water, myPos);
            if(uniformRain) {
                myWater += rainAmount;
            } else {
                vec2 toCenter = pos - myPos;
                float dist = length(toCenter);
                float add = 0;
                if(dist < radius) {
                    add = max(0,(radius-dist)) * norm;
                }
                myWater += add;
            }
            imageStore(water, myPos, vec4(myWater));
        }
    };
    void rain() {
        placeWaterShader.use();
        placeWaterShader.uniform.uniformRain = true;
        placeWaterShader.uniform.rainAmount = rainRate * deltaTime;
        glBindImageTexture(0, water, 0, GL_FALSE, 0, GL_READ_WRITE, GL_R32F); glError();
        glDispatchCompute(workGroupsX, workGroupsY, 1); glError();
        glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
        placeWaterShader.use(false);
    }


    //  water[0](global), height[0](global), soil[0](global), waterFlows[0]   ->    waterFlows[1]
    void calculateFlows() {
        flowShader.use();
        setConstants(flowShader);
        float flowMultiplier = pipeArea * gravity * deltaTime;
        flowShader.uniform.flowMultiplier = flowMultiplier;
        glBindImageTexture(0, water,     0, GL_FALSE, 0, GL_READ_ONLY, GL_R32F); glError();
        glBindImageTexture(1, soil,      0, GL_FALSE, 0, GL_READ_ONLY, GL_R32F); glError();
        glBindImageTexture(2, height,    0, GL_FALSE, 0, GL_READ_ONLY, GL_R32F); glError();
        glBindImageTexture(3, waterFlow, 0, GL_FALSE, 0, GL_READ_WRITE, GL_RGBA32F); glError();
        glDispatchCompute(workGroupsX, workGroupsY, 1); glError();
        glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
        flowShader.use(false);
    }


    string flowShaderSource = q{

        layout(binding=0, r32f) readonly uniform image2D water;
        layout(binding=1, r32f) readonly uniform image2D soil;
        layout(binding=2, r32f) readonly uniform image2D height;
        layout(binding=3, rgba32f) uniform image2D waterFlow; //readwrite
        uniform ivec2 size;

        uniform float flowMultiplier;
        uniform float deltaTime;

        ivec2 clampPos(ivec2 pos) {
            return clamp(pos, ivec2(0,0), size-ivec2(1,1));
        }

        void main() {
            float[4] flows; // Out-flows. Flow * time = volume.
            ivec2[4] offsets = ivec2[4](ivec2(1, 0), ivec2(0, -1), ivec2(-1, 0), ivec2(0, 1));
            //Reads outside the image return 0. YEAH!
            ivec2 myPos = ivec2(gl_GlobalInvocationID.xy);
            float myWater =  imageLoad(water, myPos);
            float mySoil =   imageLoad(soil, myPos);
            float myHeight = imageLoad(height, myPos);
            float myTotal = myHeight + mySoil + myWater;
            vec4 myFlow = imageLoad(waterFlow, myPos);
            flows = float[4](myFlow.r, myFlow.g, myFlow.b, myFlow.a);
            for(int dir = 0; dir < 4; dir++) {
                ivec2 offset = offsets[dir];
                float otherWater  = imageLoad(water, clampPos(myPos + offset));
                float otherSoil   = imageLoad(soil, clampPos(myPos + offset));
                float otherHeight = imageLoad(height, clampPos(myPos + offset));
                float heightDiff = myTotal - otherHeight - otherSoil - otherWater;
                flows[dir] = max(0, flows[dir] + flowMultiplier * heightDiff);
            }
            float flowSum = flows[0] + flows[1] + flows[2] + flows[3];
            myFlow = vec4(flows[0], flows[1], flows[2], flows[3]);
            float flowHeight = deltaTime * flowSum;
            if(flowHeight > myWater) {
                myFlow = myFlow * myWater / flowHeight;
            }
            imageStore(waterFlow, myPos, myFlow);
        }
    };

    // water[0](local), waterFlows[1](local) -> water[1]
    void computeWater() {
        waterShader.use();
        waterShader.uniform.deltaTime = deltaTime;
        waterShader.uniform.size = vec2i(cast(int)sizeX, cast(int)sizeY);
        glBindImageTexture(0, water, 0, GL_FALSE, 0, GL_READ_WRITE, GL_R32F); glError();
        glBindImageTexture(1, waterFlow, 0, GL_FALSE, 0, GL_READ_ONLY, GL_RGBA32F); glError();
        glDispatchCompute(workGroupsX, workGroupsY, 1); glError();
        glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
        waterShader.use(false);
    }

    string waterShaderSource = q{

        layout(binding=0, r32f) uniform image2D water; //readwrite
        layout(binding=1, rgba32f) readonly uniform image2D waterFlow;
        uniform float deltaTime;
        uniform ivec2 size;

        bool inside(ivec2 pos) {
            return pos == clamp(pos, ivec2(0,0), size-ivec2(1,1));
        }
        void main() {
            ivec2 myPos = ivec2(gl_GlobalInvocationID.xy);
            float myWater = imageLoad(water, myPos);
            vec4 myFlow = imageLoad(waterFlow, myPos);
            float flowDiff = -(myFlow.r + myFlow.g + myFlow.b + myFlow.a);
            if(flowDiff > 0) {
                //TODO: Debug-set a variable if error
            }
            ivec2 right = myPos+ivec2( 1,  0);
            ivec2 above = myPos+ivec2( 0, -1);
            ivec2 left  = myPos+ivec2(-1,  0);
            ivec2 below = myPos+ivec2( 0,  1);
            float flowFromRight = inside(right) ? imageLoad(waterFlow, right).z : 0.0;
            float flowFromAbove = inside(above) ? imageLoad(waterFlow, above).w : 0.0;
            float flowFromLeft  = inside(left)  ? imageLoad(waterFlow, left).x  : 0.0;
            float flowFromBelow = inside(below) ? imageLoad(waterFlow, below).y : 0.0;
            flowDiff += flowFromRight + flowFromAbove + flowFromLeft + flowFromBelow;
            float flowVolume = flowDiff * deltaTime;
            float endWaterHeight = max(0, myWater + flowVolume);
            imageStore(water, myPos, vec4(endWaterHeight));
        }
    };


    // averageWater(water[0], water[1]), waterFlows[1]   ->   velocity[0]
    void computeVelocity() {
        velocityShader.use();
        setConstants(velocityShader);
        glBindImageTexture(0, water, 0, GL_FALSE, 0, GL_READ_ONLY, GL_R32F); glError();
        glBindImageTexture(1, waterFlow, 0, GL_FALSE, 0, GL_READ_ONLY, GL_RGBA32F); glError();

        glBindImageTexture(2, velocity, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RG32F); glError();
        glDispatchCompute(workGroupsX, workGroupsY, 1); glError();
        glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
        velocityShader.use(false);
    }

    string velocityShaderSource = q{
        layout(binding=0, r32f) readonly uniform image2D water;
        layout(binding=1, rgba32f) readonly uniform image2D waterFlow;
        layout(binding=2, rg32f) writeonly uniform image2D velocity;
        uniform ivec2 size;
        uniform float deltaTime;

        bool inside(ivec2 pos) {
            return pos == clamp(pos, ivec2(0,0), size-ivec2(1,1));
        }
        void main() {
            ivec2 myPos = ivec2(gl_GlobalInvocationID.xy);

            float myWater = imageLoad(water, myPos);
            vec4 myFlow = imageLoad(waterFlow, myPos);
            float[4] flows = float[4](myFlow.r, myFlow.g, myFlow.b, myFlow.a);

            ivec2 right = myPos+ivec2( 1,  0);
            ivec2 above = myPos+ivec2( 0, -1);
            ivec2 left  = myPos+ivec2(-1,  0);
            ivec2 below = myPos+ivec2( 0,  1);
            float flowFromRight = inside(right) ? imageLoad(waterFlow, right).z : 0.0;
            float flowFromAbove = inside(above) ? imageLoad(waterFlow, above).w : 0.0;
            float flowFromLeft  = inside(left)  ? imageLoad(waterFlow, left).x  : 0.0;
            float flowFromBelow = inside(below) ? imageLoad(waterFlow, below).y : 0.0;
            float flowToRight = 0.5 * (flowFromLeft + flows[0] - flows[2] - flowFromRight );
            float flowToDown =  0.5 * (flowFromAbove + flows[3] - flows[1] - flowFromBelow );
            float velocityToRight = 0;
            float velocityToDown = 0;

            if(myWater < 0.1) { //  Otherwise sillily high velocity values.
                velocityToRight = 0;
                velocityToDown = 0;
            } else {
                velocityToRight = flowToRight / myWater;
                velocityToDown = flowToDown / myWater;
                //velocityToRight = -5;
                //velocityToDown = 5;
            }

            imageStore(velocity, myPos, vec4(velocityToRight, velocityToDown, 0.0, 0.0));
        }
    };


    // height[0](global), soil[0](global), velocity[0](local), sediment[0](local) -> height[1], soil[1], sediment[0]
    void computeSediment() {
        sedimentShader.use();
        sedimentShader.uniform.waterDepthMax = waterDepthMax;
        sedimentShader.uniform.sedimentCapacity = sedimentCapacity;
        sedimentShader.uniform.depositionConstant = depositionConstant;
        sedimentShader.uniform.dissolutionConstant = dissolutionConstant;
        sedimentShader.uniform.deltaTime = deltaTime;
        glBindImageTexture(0, velocity,  0, GL_FALSE, 0, GL_READ_ONLY, GL_RG32F); glError();
        glBindImageTexture(1, height,    0, GL_FALSE, 0, GL_READ_ONLY, GL_R32F); glError();
        glBindImageTexture(2, soil,      0, GL_FALSE, 0, GL_READ_ONLY, GL_R32F); glError();
        glBindImageTexture(3, water,     0, GL_FALSE, 0, GL_READ_WRITE, GL_R32F); glError();
        glBindImageTexture(4, sediment,  0, GL_FALSE, 0, GL_READ_WRITE, GL_R32F); glError();

        glBindImageTexture(5, newHeight, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_R32F); glError();
        glBindImageTexture(6, newSoil,   0, GL_FALSE, 0, GL_WRITE_ONLY, GL_R32F); glError();
        glDispatchCompute(workGroupsX, workGroupsY, 1); glError();
        glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
        sedimentShader.use(false);
    }
    string sedimentShaderSource = q{

        layout(binding=0, rg32f) readonly uniform image2D velocity;
        layout(binding=1, r32f) readonly uniform image2D height;
        layout(binding=2, r32f) readonly uniform image2D soil;
        layout(binding=3, r32f) uniform image2D water;
        layout(binding=4, r32f) uniform image2D sediment;
        layout(binding=5, r32f) writeonly uniform image2D newHeight;
        layout(binding=6, r32f) writeonly uniform image2D newSoil;
        uniform ivec2 size;

        uniform float waterDepthMax;
        uniform float sedimentCapacity;

        uniform float depositionConstant;
        uniform float dissolutionConstant;
        uniform float deltaTime;

        float depthCapacityModifier(float waterDepth) {
            return clamp(1.0 - waterDepth / waterDepthMax, 0.0, 1.0 );
            //return 1.0;
        }

        float calculateCapacity(float waterDepth, vec2 waterVelocity) {
            float velLength = length(waterVelocity);
            //velLength = 5;
            float terrainModifier = 1.0;
            return sedimentCapacity * 
                velLength * 
                terrainModifier *
                depthCapacityModifier(waterDepth);
        }

        void main() {
            //// BEGIN SEDIMENT ////
            // height[0](global), soil[0](global), velocity[0](local), sediment[0](local) -> height[1], soil[1], sediment[1]
            ivec2 myPos = ivec2(gl_GlobalInvocationID.xy);
            float myWater   = imageLoad(water, myPos);
            float myHeight  = imageLoad(height, myPos);
            float mySoil    = imageLoad(soil, myPos);
            float mySediment= imageLoad(sediment, myPos);
            vec2 myVelocity = imageLoad(velocity, myPos).xy;


            float finalHeight = myHeight;
            float finalSoil = mySoil;
            float finalSediment = mySediment;
            float finalWater = myWater;

            float capacity = calculateCapacity(myWater, myVelocity);
            float sedimentExcess = mySediment - capacity; // if can carry 5 but has 6 then is 1
            sedimentExcess *= deltaTime;
            if(sedimentExcess >= 0) {
                //Deposit percentage of excess
                float toDeposit = depositionConstant * sedimentExcess;
                finalSediment = mySediment - toDeposit;
                finalSoil = mySoil + toDeposit;
                finalWater -= toDeposit;
            } else {
                float stuffToAbsorb = -sedimentExcess; // -sedímentExcess = how much more we can carry
                float soilDissolutionConstant = dissolutionConstant;
                float soilToAbsorb = soilDissolutionConstant * stuffToAbsorb;
                if(soilToAbsorb < mySoil) {
                    mySediment += soilToAbsorb;
                    finalWater += soilToAbsorb;
                    finalSoil = mySoil - soilToAbsorb;
                } else {
                    mySediment += mySoil;
                    myWater += mySoil;
                    stuffToAbsorb -= mySoil;
                    finalSoil = 0;

                    float materialDissolutionConstant = dissolutionConstant;
                    float materialToAbsorb = materialDissolutionConstant * stuffToAbsorb;
                    materialToAbsorb = soilDissolutionConstant * stuffToAbsorb;
                    mySediment += materialToAbsorb;
                    finalWater += materialToAbsorb;
                    finalHeight -= materialToAbsorb;
                }
                finalSediment = mySediment;
            }

            imageStore(newHeight, myPos, vec4(finalHeight));
            imageStore(sediment, myPos, vec4(finalSediment));
            imageStore(newSoil, myPos, vec4(finalSoil));
            //imageStore(water, myPos, vec4(finalWater));
            imageStore(water, myPos, vec4(myWater));
            // height[0](global), soil[0](global), velocity[0](local), sediment[0](local) -> height[1], soil[1], sediment[1]
            //// END SEDIMENT ////
        }
    };

    // sediment[0](global), velocity[0](global) -> sediment[1]
    void transportSediment(){

        transportSedimentShader.use();
        setConstants(transportSedimentShader);
        BindTexture(sediment, 0);
        glBindImageTexture(0, velocity, 0, GL_FALSE, 0, GL_READ_ONLY, GL_RG32F); glError();

        glBindImageTexture(1, newSediment, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_R32F); glError();
        glMemoryBarrier(GL_TEXTURE_FETCH_BARRIER_BIT);
        glDispatchCompute(workGroupsX, workGroupsY, 1); glError();
        glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
        transportSedimentShader.use(false);
    }
    string transportSedimentShaderSource = q{

        layout(binding=0) uniform sampler2D sediment;
        layout(binding=0, rg32f) readonly uniform image2D velocity;
        layout(binding=1, r32f) writeonly uniform image2D newSediment;

        uniform ivec2 size;
        uniform float deltaTime;

        void main() {
            ivec2 myPos = ivec2(gl_GlobalInvocationID.xy);

            vec2 myVel  = imageLoad(velocity, myPos).xy;
            myVel = myVel; // * deltaTime;

            vec2 sedimentSamplePos = vec2(1.0 / size.x, 1.0 / size.y) * (myPos + vec2(0.5, 0.5) - myVel);
            float finalSediment = texture(sediment, sedimentSamplePos);
            imageStore(newSediment, myPos, vec4(finalSediment));
        }
    };

    // water[0] -> water[0]
    void evaporate() {
        evaporateShader.use();
        evaporateShader.uniform.evaporationConstant = evaporationConstant;
        setConstants(evaporateShader);
        glBindImageTexture(0, water, 0, GL_FALSE, 0, GL_READ_WRITE, GL_R32F); glError();
        glDispatchCompute(workGroupsX, workGroupsY, 1); glError();
        glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
        transportSedimentShader.use(false);
    }
    string evaporateShaderSource= q{
        layout(binding=0, r32f) uniform image2D water;

        uniform float evaporationConstant;
        uniform float deltaTime;

        void main() {
            ivec2 myPos = ivec2(gl_GlobalInvocationID.xy);
            float waterLevel = imageLoad(water, myPos);
            waterLevel = waterLevel * (1 - evaporationConstant * deltaTime);
            imageStore(water, myPos, vec4(waterLevel));
        }
    };


    // height[1](global), soil[1](global) -> height[0](global), soil[0](global)
    void talusFlow() {
        flowTalusShader.use();
        setConstants(flowTalusShader);
        flowTalusShader.uniform.ROCK = 1;
        flowTalusShader.uniform.flowMultiplier = talusFlowMultiplier;
        flowTalusShader.uniform.talusLimit = talusLimit;
        glBindImageTexture(0, newHeight, 0, GL_FALSE, 0, GL_READ_ONLY, GL_R32F); glError();
        glBindImageTexture(1, newSoil, 0, GL_FALSE, 0, GL_READ_ONLY, GL_R32F); glError();

        glBindImageTexture(2, talusMovement1,   0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RGBA32F); glError();
        glBindImageTexture(3, talusMovement2,   0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RGBA32F); glError();
        glDispatchCompute(workGroupsX, workGroupsY, 1); glError();
        glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

        flowTalusShader.use(false);
    }

    string flowTalusShaderSource = q{

        layout(binding=0, r32f) readonly uniform image2D height;
        layout(binding=1, r32f) readonly uniform image2D soil;
        layout(binding=2, rgba32f) writeonly uniform image2D talusFlow1;
        layout(binding=3, rgba32f) writeonly uniform image2D talusFlow2;
        uniform ivec2 size;

        uniform float flowMultiplier;
        uniform float talusLimit;
        uniform float deltaTime;

        ivec2 clampPos(ivec2 pos) {
            return clamp(pos, ivec2(0,0), size-ivec2(1,1));
        }

        void main() {
            float[8] flows = float[8](0.0, 0.0, 0.0, 0.0,
                                      0.0, 0.0, 0.0, 0.0);
            ivec2[8] offsets = ivec2[8](ivec2(1, 0), ivec2(0, -1), ivec2(-1, 0), ivec2(0, 1),
                                        ivec2(1, 1), ivec2(1, -1), ivec2(-1, 1), ivec2(-1, -1));

            ivec2 myPos = ivec2(gl_GlobalInvocationID.xy);
            float myHeight = imageLoad(height, myPos);
            float myTotal = myHeight;
            float maxDiff = 0;
            float flowSum = 0;
            for(int dir = 0; dir < 8; dir++) {
                ivec2 offset = offsets[dir];
                float otherHeight = imageLoad(height, clampPos(myPos + offset));
                float heightDiff = myTotal - otherHeight;
                if(heightDiff > talusLimit) {
                    maxDiff = max(maxDiff, heightDiff);
                    flows[dir] = heightDiff;
                    flowSum += heightDiff;
                }
            }

            // Div with flowsum to normalize to sum up to 1
            // Mul with ½maxDiff to set amount to flow out.
            if(flowSum != 0) {
                float mod = maxDiff * 0.5 / flowSum;
                for(int dir = 0; dir < 8; dir++) {
                    flows[dir] *= mod;
                }
            }
            vec4 tf1 = vec4(flows[0], flows[1], flows[2], flows[3]);
            vec4 tf2 = vec4(flows[4], flows[5], flows[6], flows[7]);
            imageStore(talusFlow1, myPos, tf1);
            imageStore(talusFlow2, myPos, tf2);
        }
    };
    void talusMove() {
        moveTalusShader.use();
        setConstants(moveTalusShader);
        moveTalusShader.uniform.ROCK = 1;
        moveTalusShader.uniform.flowMultiplier = talusFlowMultiplier;
        glBindImageTexture(0, newHeight, 0, GL_FALSE, 0, GL_READ_ONLY, GL_R32F); glError();
        glBindImageTexture(1, newSoil, 0, GL_FALSE, 0, GL_READ_ONLY, GL_R32F); glError();
        glBindImageTexture(2, talusMovement1,   0, GL_FALSE, 0, GL_READ_ONLY, GL_RGBA32F); glError();
        glBindImageTexture(3, talusMovement2,   0, GL_FALSE, 0, GL_READ_ONLY, GL_RGBA32F); glError();
        glBindImageTexture(4, height, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_R32F); glError();
        glBindImageTexture(5, soil, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_R32F); glError();
        glDispatchCompute(workGroupsX, workGroupsY, 1); glError();
        glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

        moveTalusShader.use(false);

        // ONLY MODIFIES HEIGHT NOW
        swap(soil, newSoil);

    }

    string moveTalusShaderSource = q{

        layout(binding=0, r32f) readonly uniform image2D newHeight;
        layout(binding=1, r32f) readonly uniform image2D newSoil;
        layout(binding=2, rgba32f) readonly uniform image2D talusFlow1;
        layout(binding=3, rgba32f) readonly uniform image2D talusFlow2;
        layout(binding=4, r32f) writeonly uniform image2D height;
        layout(binding=5, r32f) writeonly uniform image2D soil;

        uniform ivec2 size;
        uniform float deltaTime;

        bool inside(ivec2 pos) {
            return pos == clamp(pos, ivec2(0,0), size-ivec2(1,1));
        }
        void main() {
            ivec2 myPos = ivec2(gl_GlobalInvocationID.xy);

            float myHeight = imageLoad(newHeight, myPos);
            vec4 myFlow1 = imageLoad(talusFlow1, myPos);
            vec4 myFlow2 = imageLoad(talusFlow2, myPos);

            ivec2 right = myPos+ivec2( 1,  0);
            ivec2 above = myPos+ivec2( 0, -1);
            ivec2 left  = myPos+ivec2(-1,  0);
            ivec2 below = myPos+ivec2( 0,  1);
            ivec2 c1 = myPos+ivec2(1,1);
            ivec2 c2 = myPos+ivec2(1,-1);
            ivec2 c3 = myPos+ivec2(-1,1);
            ivec2 c4 = myPos+ivec2(-1,-1);
            float flowFromRight = inside(right) ? imageLoad(talusFlow1, right).z : 0.0;
            float flowFromAbove = inside(above) ? imageLoad(talusFlow1, above).w : 0.0;
            float flowFromLeft  = inside(left)  ? imageLoad(talusFlow1, left).x  : 0.0;
            float flowFromBelow = inside(below) ? imageLoad(talusFlow1, below).y : 0.0;
            float flowFromC1    = inside(c1)    ? imageLoad(talusFlow2, c1).w : 0.0;
            float flowFromC2    = inside(c2)    ? imageLoad(talusFlow2, c2).z : 0.0;
            float flowFromC3    = inside(c3)    ? imageLoad(talusFlow2, c3).y : 0.0;
            float flowFromC4    = inside(c4)    ? imageLoad(talusFlow2, c4).x : 0.0;

            float finalHeight = myHeight + deltaTime * (
                    flowFromRight + flowFromAbove + flowFromLeft + flowFromBelow +
                    flowFromC1 + flowFromC2 + flowFromC3 + flowFromC4
                    -myFlow1.x - myFlow1.y - myFlow1.z - myFlow1.w
                    -myFlow2.x - myFlow2.y - myFlow2.z - myFlow2.w
                                                        );

            imageStore(height, myPos, vec4(finalHeight));
        }
    };


}


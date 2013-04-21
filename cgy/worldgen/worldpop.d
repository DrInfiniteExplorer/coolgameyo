
module worldgen.worldpop;

import std.random;

import worldgen.maps;
import random.random;
import random.randsource;


immutable CityKernelSize = 20;
immutable WaterKernelSize = 4;
immutable NearCityDistance = 30;

immutable StartCityCount = 100;

immutable roadVertShader = q{
    #version 430
    layout(location = 0) in ivec2 pos;

    uniform mat4 transform;
    layout(binding = 0) uniform sampler2D height;
    layout(binding = 1) uniform sampler2D h2;
    layout(binding = 2) uniform sampler2D h3;
    uniform vec2 cellSize;

    out vec3 transformedPos;
    flat out ivec2 posss;

    float get(ivec2 pos) {
        float h = texelFetch(height, pos, 0);
        h += texelFetch(h2, pos, 0);
        //h += texelFetch(h3, pos, 0);
        return h;
    }

    void main() {
        float h = get(pos);
        vec3 vert = vec3(pos * cellSize, h);
        gl_Position = transform * vec4(vert, 1.0);
        transformedPos = (transform * vec4(vert, 1.0)).xyz;
        posss = pos;

        float water = clamp(texelFetch(h3, pos, 0).x, 0.0, 1.0);
        //clr = mix(col, vec3(0.1, 0.1, 0.9), water);
    }
};
immutable roadFragShader = q{
    #version 430

    in vec3 transformedPos;
    flat in ivec2 posss;
    layout(location = 0) out vec4 frag_color;
    layout(location = 1) out vec4 light;
    //layout(binding=2, r16f) readonly uniform image2D h3;
    //layout(location = 2) out vec4 depth;
    layout(binding = 0) uniform sampler2D height;
    layout(binding = 1) uniform sampler2D h2;
    layout(binding = 2) uniform sampler2D h3;


    void main() {
        light = vec4(1.0, 1.0, 1.0, 1.0);
        frag_color = vec4(1.0, 0.0, 0.0, 1.0);
    }
};

mixin template WorldPopulation() {

    import graphics.ogl;
    import graphics.shader;
    import graphics.heightmap : Heightmap, renderLoop;
    import graphics.camera : Camera;
    import util.traits : DownwardDelegate;
    import util.util;

    struct CityData {
        vec2i location;
        int[] closestCities;

        int population;
        float farmProduce;
        float fishProduce;
        float foodStore = 0.0;
        
        float craftProduce;
        float wealth = 0.0;
    }

    struct RoadVertex {
        vec2i pos;
        bool finalPosition;
    }

    RoadVertex[] roadVertices;
    int[2][] roadEdges;

    int[] getRoadEdges(int roadVert) {
        int[] ret;
        foreach(size_t idx, edge ; roadEdges) {
            if(edge[0] == roadVert || edge[1] == roadVert) {
                ret ~= cast(int)idx;
            }
        }
        return ret;
    }

    CityData[] cityData;

    bool cityNear(vec2i pos) {
        foreach(data ; cityData) {
            if(data.location.getDistanceSQ(pos) < (NearCityDistance ^^ 2) ) {
                return true;
            }
        }
        return false;
    }

    Random popGen;
    void generateLife() {

        initGenerateLife();
        scope(exit) {
            deinitGenerateLife();
        }
        popGen.seed(walkSeed);


        RoadVertex cityVert;
        cityVert.finalPosition = true;
        foreach(size_t idx; 0 .. StartCityCount) {
            CityData data;
            do {
                float score = 0.0;
                do {
                    int X = uniform(0, TotalSamples, popGen);
                    int Y = uniform(0, TotalSamples, popGen);
                    foreach(x, y ; Range2D(X - CityKernelSize / 2, X + CityKernelSize / 2,
                                       Y - CityKernelSize / 2, Y + CityKernelSize / 2)) {
                        float tmpScore = evaluateVillageScore(vec2i(x, y));
                        if(tmpScore > score) {
                            score = tmpScore;
                            data.location.set(x, y);
                        }
                    }
                } while(score == 0.0);

            } while(cityNear(data.location));
            cityVert.pos = data.location;
            roadVertices ~= cityVert;
            data.population = 10;
            cityData ~= data;
        }


        float[StartCityCount] cityDistance;
        size_t[StartCityCount] index;
        foreach(size_t idx, ref data ; cityData) {
            foreach(size_t otherIdx, ref otherData ; cityData) {
                cityDistance[otherIdx] = (data.location - otherData.location).convert!float.getLength();
            }
            size_t[] arr = index;
            float[] rra = cityDistance;
            makeIndex(rra, arr); // Lol, does not work with fixed size arrays. Need the two lines above.
            data.closestCities.length = 5;
            foreach(idxIdx ; 0 .. 5) {
                data.closestCities[idxIdx] = cast(int)index[idxIdx+1];
                writeln(index[idxIdx], " ", idx);
            }
        }

        int[2][] cityConnections;
        foreach(size_t idx, ref data ; cityData) {
            foreach(other ; data.closestCities) {
                int i1 = cast(int)idx;
                int i2 = other;
                if(i1 < i2) {
                    swap(i1, i2);
                }
                int[2] tmp = makeStackArray(i1, i2);
                if(countUntil(cityConnections, tmp) == -1) {
                    cityConnections ~= tmp;
                }
            }
        }

        bool less(int[2] idx1, int[2] idx2) {
            return (roadVertices[idx1[0]].pos - roadVertices[idx1[1]].pos).getLengthSQ()
                < (roadVertices[idx2[0]].pos - roadVertices[idx2[1]].pos).getLengthSQ;
        }

        // Start by connecting the shortest roads; long roads may take advantage of existing short roads and bridges,
        //  which are "more likely" to be built/developed before long long routes.
        sort!less(cityConnections);
        foreach(size_t idx, connection ; cityConnections) {
            msg(idx, " of ", cityConnections.length);
            computeRoad(connection[0], connection[1]);
        }
        foreach(lengths ; roadLengths) {
            msg(lengths[0] , " -> ", lengths[1]);
        }


        render();
    }

    float[2][] roadLengths;

    int cnt = 0;
    void computeRoad(int startCityVertex, int endCityVertex) {
        if(cnt > 3) return;
        cnt++;
        msg("Road between ", startCityVertex, " and ", endCityVertex);
        //startCityVertex = 0;
        //endCityVertex = 1;

        auto start = roadVertices[startCityVertex].pos;
        auto end   = roadVertices[endCityVertex].pos;
        //start.set(0, 0);
        //end.set(0, 2);

        roadCompute.use();
        roadCompute.uniform.startPos = start;
        roadCompute.uniform.endPos = end;

        float highValue = WorldSize * 10;
        FillTexture(roadDistanceTex, highValue, 0, 0, 0);
        glBindImageTexture(0, roadHeightTex,   0, GL_FALSE, 0, GL_READ_ONLY,  GL_R32F); glError();
        glBindImageTexture(1, roadWaterTex,    0, GL_FALSE, 0, GL_READ_ONLY,  GL_R32F); glError();
        glBindImageTexture(2, roadDistanceTex, 0, GL_FALSE, 0, GL_READ_WRITE, GL_R32F); glError();
        glBindImageTexture(3, roadRoadTex,     0, GL_FALSE, 0, GL_READ_ONLY,  GL_R32F); glError();


        int maxPathLength = start.getDistance(end) * 2;
        msg("dist ", maxPathLength / 2);

        foreach(iter ; 0 .. maxPathLength) {
            glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
            glDispatchCompute(TotalSamples / 16, TotalSamples / 16, 1); glError();
        }
        glMemoryBarrier(GL_TEXTURE_UPDATE_BARRIER_BIT);
        roadCompute.use(false);
        glBindTexture(GL_TEXTURE_2D, roadDistanceTex);
        glGetTexImage(GL_TEXTURE_2D, 0, GL_RED, GL_FLOAT, roadTmp.ptr); glError();
        //heightMaps.heightData[] = tmp[];
        //heightMaps.heightData[] -= 103_000.0;




        float get(int x, int y) {
            return roadTmp[y * TotalSamples + x];
        }

        vec2i pt = end;
        vec2i oldPt;
        vec2i[] path = [];
        float minScore = float.max;
        bool done = false;
        while(!done) {
            // Examine neighbors, find with smallest value, go there.
            oldPt = pt;
            foreach(newPos ; neighbors2D(pt)) {
                if(newPos == start) {
                    done = true;
                    break;
                }
                if(newPos.x < 0 || newPos.y < 0 || newPos.x == TotalSamples || newPos.y == TotalSamples) continue;
                float score = get(newPos.x, newPos.y);
                if(score < minScore) {
                    //msg(minScore, " ", score);
                    minScore = score;
                    pt = newPos;
                }
            }
            if(done) {
                break;
            } else {
                if(pt == oldPt) {
                    foreach(newPos ; neighbors2D(pt)) {
                        float score = get(newPos.x, newPos.y);
                        msg(score);
                    }
                    // No solution! :S
                    msg("No solution found between ", start, " and ", end);                    
                    msg(get(start.x, start.y));
                    msg(get(end.x, end.y));
                    roadEdges ~= makeStackArray(endCityVertex, startCityVertex);


                    return;
                }
                path ~= pt;
            }
        }
        if(!done) {
            msg("Incomplete road!");
        }

        /*
        Image img;
        img.fromGLFloatTex(roadHeightTex, 0, 2000);
        img.setPixel(start.x, start.y, 0, 255, 0);
        img.setPixel(end.x, end.y, 0, 0, 255);
        img.save("height.png");
        img.fromGLFloatTex(roadWaterTex, 0, 50);
        img.setPixel(start.x, start.y, 0, 255, 0);
        img.setPixel(end.x, end.y, 0, 0, 255);
        img.save("water.png");
        img.fromGLFloatTex(roadDistanceTex, 0, 2000);
        img.setPixel(start.x, start.y, 0, 255, 0);
        img.setPixel(end.x, end.y, 0, 0, 255);
        foreach(_pt ; path) {
            img.setPixel(_pt.x, _pt.y, 192, 192, 192);
        }
        img.save("distance.png");
        //*/


        glBindTexture(GL_TEXTURE_2D, roadRoadTex);
        glGetTexImage(GL_TEXTURE_2D, 0, GL_RED, GL_FLOAT, roadTmp.ptr); glError();

        roadLengths ~= makeStackArray( cast(float)start.getDistance(end), cast(float)path.length + 2);


        int offset = cast(int)roadVertices.length;
        roadEdges ~= makeStackArray(endCityVertex, offset);
        foreach(size_t idx, p ; path) {
            roadVertices ~= RoadVertex(p);
            roadEdges ~= makeStackArray(offset + cast(int)idx, offset + cast(int)idx+1);
            roadTmp[p.y * TotalSamples + p.x] = 1.0;
        }
        roadEdges[$-1][1] = startCityVertex;

        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, TotalSamples, TotalSamples, GL_RED, GL_FLOAT, roadTmp.ptr); glError();
        //msg(roadEdges);
    }

    uint roadHeightTex;
    uint roadWaterTex;
    uint roadDistanceTex;
    uint roadRoadTex;
    float[] roadTmp;
    ShaderProgram!() roadCompute;
    void initGenerateLife() {
        roadCompute = new ShaderProgram!();
        roadCompute.compileCompute(roadComputeShader);
        roadCompute.link();
        roadCompute.use();
        roadCompute.uniform.size = vec2i(TotalSamples);
        roadCompute.uniform.SampleIntervall = cast(float)SampleIntervall;
        roadTmp = heightMaps.heightData.dup;
        roadTmp[] += heightMaps.soilData[];
        roadHeightTex = Create2DTexture!(GL_R32F, float)(TotalSamples, TotalSamples, roadTmp.ptr);
        roadWaterTex = Create2DTexture!(GL_R32F, float)(TotalSamples, TotalSamples, heightMaps.waterData.ptr);
        roadDistanceTex = Create2DTexture!(GL_R32F, float)(TotalSamples, TotalSamples, null);
        roadRoadTex = Create2DTexture!(GL_R32F, float)(TotalSamples, TotalSamples, null);
        FillTexture(roadRoadTex, 0.0, 0, 0, 0);
    }

    void deinitGenerateLife() {
        roadCompute.destroy();
        DeleteTextures(roadHeightTex, roadWaterTex, roadDistanceTex, roadRoadTex);
        roadTmp = null;
    }

    immutable roadComputeShader = q{
        #version 430
        layout(local_size_x = 16 , local_size_y = 16, local_size_z = 1) in;

        layout(binding=0, r32f) readonly uniform image2D height;
        layout(binding=1, r32f) readonly uniform image2D water;
        layout(binding=2, r32f) uniform image2D distance;
        layout(binding=3, r32f) uniform image2D road;
        uniform ivec2 startPos;
        uniform ivec2 endPos;
        uniform ivec2 size;
        uniform float SampleIntervall;


        float computeDistance(ivec2 from, float myHeight, float myWater, float myRoad) {
            if(myRoad != 0.0) {
                return myRoad;
            }
            float slope = (myHeight - imageLoad(height, from)) / SampleIntervall;
            slope = abs(slope);
            float distance = 1 + 4.0 * slope + 6.0 * myWater;
            return distance;
        }

        void main() {
            ivec2 myPos = ivec2(gl_GlobalInvocationID.xy);
            float myHeight = imageLoad(height, myPos);
            float myWater = imageLoad(water, myPos);
            float myRoad = imageLoad(road, myPos);

            float myDistance = imageLoad(distance, myPos);

            ivec2 lleft = myPos + ivec2(-1, 0);
            ivec2 rright = myPos + ivec2(1, 0);
            ivec2 aabove = myPos + ivec2(0, -1);
            ivec2 bbelow = myPos + ivec2(0, 1);

            if(myPos == startPos) {
                imageStore(distance, myPos, vec4(0.0));
                myDistance = 0.0;
            }
            memoryBarrierImage();



            float highValue = 100000;
            float above = highValue;
            float below = highValue;
            float right = highValue;
            float left  = highValue;
            if(myPos.y > 0) {
                above = imageLoad(distance, aabove).x;
            }
            if(myPos.x > 0) {
                left = imageLoad(distance, lleft).x;
            }
            if(myPos.y < size.y-1) {
                below = imageLoad(distance, bbelow).x;
            }
            if(myPos.x < size.x-1) {
                right = imageLoad(distance, rright).x;
            }

            float finalDistance = myDistance;
            if(above < myDistance) {
                finalDistance = min(finalDistance, above + computeDistance( aabove, myHeight, myWater, myRoad));
            }
            if(below < myDistance) {
                finalDistance = min(finalDistance, below + computeDistance( bbelow, myHeight, myWater, myRoad));
            }
            if(left < myDistance) {
                finalDistance = min(finalDistance, left + computeDistance( lleft, myHeight, myWater, myRoad));
            }
            if(right < myDistance) {
                finalDistance = min(finalDistance, right + computeDistance( rright, myHeight, myWater, myRoad));
            }

            if(finalDistance < myDistance) {
                myDistance = finalDistance;
                imageStore(distance, myPos, vec4(finalDistance));
            }
        }
    };

    void render() {

        uint vertBuff, idxBuff;
        glGenBuffers(1, &vertBuff); glError();
        glGenBuffers(1, &idxBuff); glError();
        glBindBuffer(GL_ARRAY_BUFFER, vertBuff); glError();
        glBufferData(GL_ARRAY_BUFFER, roadVertices.length * roadVertices[0].sizeof, roadVertices.ptr, GL_STATIC_DRAW); glError();
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, idxBuff);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, roadEdges.length * roadEdges[0].sizeof, roadEdges.ptr, GL_STATIC_DRAW); glError();

        HMap height = new HMap;
        scope(exit) {
            height.destroy();
        }
        height.depth = WorldSize;
        height.width = WorldSize;

        uint heightTex = Create2DTexture!(GL_R32F,float)(TotalSamples, TotalSamples, heightMaps.heightData.ptr);
        uint soilTex = Create2DTexture!(GL_R32F,float)(TotalSamples, TotalSamples, heightMaps.soilData.ptr);
        uint waterTex = Create2DTexture!(GL_R32F,float)(TotalSamples, TotalSamples, heightMaps.waterData.ptr);
        scope(exit) {
            DeleteTextures(heightTex, soilTex, waterTex);
        }
        uint[3] texes = makeStackArray(heightTex, soilTex, waterTex);
        
        height.loadTexture(texes, TotalSamples, TotalSamples);
        height.setColor(vec3f(0.4, 0.7, 0.3));

        bool done = false;
        Camera camera = new Camera;
        camera.speed *= 7;
        camera.farPlane *= 25;
        //camera.setPosition(vec3d(WorldSize / 3.0, -(WorldSize / 5.0), WorldSize / 3.0));
        //camera.setTargetDir(vec3d(0.1, 0.7, -0.4));
        camera.setPosition(vec3d(18166.7, 17122.6, -947.274));
        camera.setTargetDir(vec3d(-0.638903, 0.42497, -0.641251));
        camera.mouseMoveEnabled = false;
        //camera.printPosition = true;


        auto roadShader = new ShaderProgram!();
        roadShader.compileVertex(roadVertShader);
        roadShader.compileFragment(roadFragShader);
        roadShader.link();
        scope(exit) {
            roadShader.destroy();
        }

        /*

        renderLoop(
            camera, 
            { return false; },
            {
                //height.render(camera, true);
                height.render(camera);
                glLineWidth(5.0);
                roadShader.use();
                roadShader.uniform.transform = camera.getProjectionMatrix * camera.getViewMatrix;
                roadShader.uniform.cellSize = vec2f(SampleIntervall);
                glBindBuffer(GL_ARRAY_BUFFER, vertBuff);
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, idxBuff);
                glVertexAttribIPointer(0u, 2, GL_INT, roadVertices[0].sizeof, cast(void*)0); glError();
                glEnableVertexAttribArray(0); glError();
                glDrawElements(GL_LINES, cast(uint)roadEdges.length * 2, GL_UNSIGNED_INT, cast(void*)0);
                //glDrawArrays(GL_LINES, 0, cast(int)roadVertices.length); glError();
                glDisableVertexAttribArray(0); glError();
                glBindBuffer(GL_ARRAY_BUFFER, 0);
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
                roadShader.use(false);
                glLineWidth(1.0);
            }
        );
        */
    }

    float evaluateVillageScore(vec2i pos) {
        vec2f slopeVect = heightMaps.getSampleSlope(pos);
        float slope = slopeVect.getLength();
        float minSlope = max(0.33, slope);
        float slopeScore = 3.0 / minSlope;

        int waterCount = 0;
        foreach(x, y ; Range2D(pos.x - WaterKernelSize / 2, pos.x + WaterKernelSize / 2,
                               pos.y - WaterKernelSize / 2, pos.y + WaterKernelSize / 2)) {
            auto waterLevel = heightMaps.getWaterValueClamp(x, y);
            if(waterLevel > 0.2) {
                waterCount++;
            }
        }
        if(heightMaps.getWaterValueClamp(pos.x, pos.y) > 0.2) return 0.0; // Cant live in water
        waterCount = min(waterCount, 5);
        float waterScore = waterCount / 5.0;

        return slopeScore * waterScore;
    }

}





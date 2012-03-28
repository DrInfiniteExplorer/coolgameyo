module heightsheets.level0;


import std.algorithm;
import std.stdio;

import heightsheets.heightsheets;
import heightsheets.level1;

import graphics.camera;
import graphics.ogl;
import graphics.shader;
import modules.module_;
import statistics;
import world.world;
import worldgen.newgen;
import util.util;

final class Level0Sheet {

    alias ShaderProgram!("offset", "VP") level0Shader;
    level0Shader shader;


    Level1Sheet level1;
    HeightSheets heightSheets;
    LayerManager layerManager;
    World world;

    this(Level1Sheet _level1) {
        level1 = _level1;
        heightSheets = level1.heightSheets;
        layerManager = heightSheets.layerManager;
        world = heightSheets.world;
        vertices.length = 100;
        colors.length = vertices.length;
    }
    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {
        destroyed = true;
        //Should also destroy any opengl stuff?
        //Or not?
    }

    void init() {
        /+_+/
        shader = new level0Shader("shaders/HeightSheetsI.vert", "shaders/HeightSheetsI.frag");
        shader.bindAttribLocation(0, "position");
        shader.bindAttribLocation(1, "normal");
        shader.bindAttribLocation(2, "color");
        shader.link();
        shader.offset      = shader.getUniformLocation("offset");
        shader.VP          = shader.getUniformLocation("VP");

    }


    void buildHeightmap(SectorNum center) {
        mixin(Time!"writeln(\"build+upload:\", usecs/1000);");


        SectorXYNum startSect = SectorXYNum(SectorXYNum(center).value - vec2i(5,5));

        vec2i baseTp = startSect.getTileXYPos().value;

        usedVertices = 0;
        auto derp = vertices.capacity;

        foreach(y ; 0 .. 10) {
            foreach(x ; 0 .. 10) {
                if(!level1.loaded[y][x]) {

                    int firstLoadedZ = int.min;
                    int lastLoadedZ = int.min;
                    int[] notLoaded;

                    double maxZ = level1.sectorMax[y * 10 + x] + center.toTilePos.value.Z;
                    double minZ = level1.sectorMin[y * 10 + x] + center.toTilePos.value.Z;

                    SectorXYNum thisSect = SectorXYNum(startSect.value + vec2i(x, y));
                    TileXYPos tp = thisSect.getTileXYPos;
                    TilePos maxTP = tp.toTilePos(cast(int)maxZ);
                    TilePos minTP = tp.toTilePos(cast(int)minZ);

                    auto maxSector = maxTP.getSectorNum();
                    auto minSector = minTP.getSectorNum();
                    foreach(z ; minSector.value.Z .. maxSector.value.Z+1) {
                        auto testNum = thisSect.getSectorNum(z);
                        bool isLoaded = world.isActiveSector(testNum) && !world.isAirSector(testNum);

                        if(isLoaded) {
                            if(firstLoadedZ == int.min) {
                                firstLoadedZ = z;
                            }
                            lastLoadedZ = z;
                        } else if(firstLoadedZ != int.min) {
                            notLoaded ~= z;
                        }

                    }
                    if(firstLoadedZ != int.min) {
                        buildLower(vec2i(x,y), firstLoadedZ); //firstLoadedZ is first loaded block, all under ok
                    }
                    if(lastLoadedZ < maxSector.value.Z) {
                        buildUpper(vec2i(x,y), lastLoadedZ+1); //lastLoadedZ+1 is first free block, then all
                    }
                    foreach(z ; notLoaded) { //These are the odd ones, who are in the middle.
                        buildMiddle(vec2i(x,y), z);
                    }
                }
            }
        }
        upload();
        if(derp != vertices.capacity) {
            writeln(derp, " -> ", vertices.capacity);
        }
    }

    int[] boxes;

    uint usedVertices;
    vec3s[] vertices;
    vec3ub[] colors;

    uint vertexVBO;
    uint colorVBO;
    uint capacity = 0;


    void upload() {
        mixin(Time!"writeln(\"upload:\", usecs/1000);");
        auto size = usedVertices;
        if(size == 0) return;
        int alloc = -1;
        if(size > capacity) {
            capacity = cast(int)(size * 1.1);
            alloc = capacity;
        }
        if(size < capacity * 0.7) {
            capacity = cast(int)(size * 1.1);
            alloc = capacity;
        }
        if(alloc != -1) {
            writeln("Re-allocing");
            if(vertexVBO) {
                glDeleteBuffers(1, &vertexVBO); glError();
            }
            if(colorVBO) {
                glDeleteBuffers(1, &colorVBO); glError();
            }
            glGenBuffers(1, &vertexVBO); glError();
            glBindBuffer(GL_ARRAY_BUFFER, vertexVBO); glError();
            glBufferData(GL_ARRAY_BUFFER, capacity * vertices[0].sizeof, null, GL_STATIC_DRAW); glError();

            glGenBuffers(1, &colorVBO); glError();
            glBindBuffer(GL_ARRAY_BUFFER, colorVBO); glError();
            glBufferData(GL_ARRAY_BUFFER, capacity * colors[0].sizeof, null, GL_STATIC_DRAW); glError();
        }
        glBindBuffer(GL_ARRAY_BUFFER, vertexVBO); glError();
        glBufferSubData(GL_ARRAY_BUFFER, 0, size * vertices[0].sizeof, vertices.ptr); glError();
        glBindBuffer(GL_ARRAY_BUFFER, colorVBO); glError();
        glBufferSubData(GL_ARRAY_BUFFER, 0, size * colors[0].sizeof, colors.ptr); glError();
    }

    void buildLower(vec2i num, int firstLoadedZ) {
        auto centerTp = level1.center.toTilePos.value;
        auto startSect = SectorXYNum(SectorXYNum(level1.center).value - vec2i(5,5));
        auto baseTp = startSect.getTileXYPos().value;

        auto thisNum = SectorXYNum(startSect.value + num);
        auto thisTp = thisNum.getTileXYPos();
        auto firstLoadedSector = thisNum.getSectorNum(firstLoadedZ);
        auto firstLoadedTilepos = firstLoadedSector.toTilePos();

        void addQuad(vec3s a, vec3s b, vec3s c, vec3s d) {
            if(vertices.length <= usedVertices+4) {
                vertices.length = cast(uint)(usedVertices + usedVertices/2);
                colors.length = vertices.length;
            }
            vertices[usedVertices+0] = a;
            vertices[usedVertices+1] = b;
            vertices[usedVertices+2] = c;
            vertices[usedVertices+3] = d;
        }
        void addQuadC(vec3ub a, vec3ub b, vec3ub c, vec3ub d) {
            colors[usedVertices+0] = a;
            colors[usedVertices+1] = b;
            colors[usedVertices+2] = c;
            colors[usedVertices+3] = d;
            usedVertices += 4;
        }

        int scale = 4;

        foreach(Y ; 0 .. SectorSize.y/scale) {
            int y = Y * scale;
            int nextZ;
            TilePos tp;
            int z;
            vec3f color;

            foreach(X ; 0 .. SectorSize.x / scale) {
                int x = X * scale;
                TileXYPos xyTp;
                if(x == 0) {
                    xyTp = TileXYPos(thisTp.value + vec2i(x, y));
                    tp = world.getTopTilePos(xyTp);
                    z = tp.value.Z;
                    color = layerManager.getBiomeColor(xyTp.value);
                }

                vec3ub col = (color * 255.0f).convert!ubyte;

                tp.value.Z = min(tp.value.Z, firstLoadedTilepos.value.Z);
                //Build top
                vec3s southWest = (tp.value-centerTp).convert!short;
                auto northWest = southWest + vec3s(0, cast(short)scale, 0);
                auto northEast = southWest + vec3s(cast(short)scale, cast(short)scale, 0);
                auto southEast = southWest + vec3s(cast(short)scale, 0, 0);
                if(z < firstLoadedTilepos.value.Z) {
                    addQuad(southWest, southEast, northEast, northWest);
                    addQuadC(col, col, col, col);
                }

                xyTp = TileXYPos(thisTp.value + vec2i(x+scale, y));
                tp = world.getTopTilePos(xyTp);
                nextZ = min(tp.value.Z, firstLoadedTilepos.value.Z);
                color = layerManager.getBiomeColor(xyTp.value);

                if(z != nextZ) {
                    auto dZ = nextZ - z;
                    auto a = northEast;
                    auto b = southEast;
                    auto c = southEast + vec3s(cast(short)0, cast(short)0, cast(short)dZ);
                    auto d = northEast + vec3s(cast(short)0, cast(short)0, cast(short)dZ);
                    addQuad(a, b, c, d);
                    addQuadC(col, col, col, col);
                }

                xyTp = TileXYPos(thisTp.value + vec2i(x, y+scale));
                auto tp_derp = world.getTopTilePos(xyTp);
                auto northZ = min(tp_derp.value.Z, firstLoadedTilepos.value.Z);
                if(z != northZ) {
                    auto dZ = northZ - z;
                    auto a = northWest;
                    auto b = northEast;
                    auto c = northEast + vec3s(cast(short)0, cast(short)0, cast(short)dZ);
                    auto d = northWest + vec3s(cast(short)0, cast(short)0, cast(short)dZ);
                    addQuad(a, b, c, d);
                    addQuadC(col, col, col, col);
                }


                z = nextZ;



                //Build front, back, left, right
            }
        }
    }
    void buildUpper(vec2i num, int firstFreeZ) {
        msg("implement buildUpper for heightsheet level 0");
    }
    void buildMiddle(vec2i num, int z) {
        msg("implement buildMiddle for heightsheet level 0");
    }


    void render(Camera camera) {
        if(usedVertices == 0) return;

        shader.use();
        vec3f toCam = (level1.center.toTilePos.value.convert!double - camera.getPosition()).convert!float;
        shader.setUniform(shader.offset, toCam);

        auto VP = camera.getProjectionMatrix() * camera.getTargetMatrix();
        shader.setUniform(shader.VP, VP);

        glBindBuffer(GL_ARRAY_BUFFER, vertexVBO); glError();
        glVertexAttribIPointer(0, 3, GL_SHORT, vertices[0].sizeof, cast(void*) 0); glError();

        glBindBuffer(GL_ARRAY_BUFFER, colorVBO); glError();
        glVertexAttribPointer(2, 3, GL_UNSIGNED_BYTE, GL_TRUE, colors[0].sizeof, cast(void*) 0); glError();

        glDisableVertexAttribArray(1); glError(); glError();
        //glDisableVertexAttribArray(2); glError(); glError();
        glDrawArrays(GL_QUADS, 0, usedVertices); glError();
        glEnableVertexAttribArray(1); glError(); glError();
        //glEnableVertexAttribArray(2); glError(); glError();

        shader.use(false);
    }
}

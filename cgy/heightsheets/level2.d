module heightsheets.level2;

import std.algorithm;
import std.stdio;
import std.math;

import heightsheets.heightsheets;
import heightsheets.level1;

import graphics.camera;
import graphics.ogl;
import graphics.shader;
import math.math;
import modules.module_;
import worldgen.maps;
import worldstate.worldstate;
import util.util;

immutable int level2SectorCount = 64; //Spans 64 sectors
immutable int level2QuadCount = level2SectorCount; //64 quads
immutable int level2VertexCount = level2QuadCount+1;
immutable int level2SampleDistance = level2SectorCount * SectorSize.x / level2QuadCount; //Distance in tiles between samples.


final class Level2Sheet {
    uint vertVBO;
    uint normVBO;
    uint colorVBO;
    uint idxVBO;

    vec3f[level2VertexCount][level2VertexCount] vertices;
    vec3f[level2VertexCount][level2VertexCount] normals;
    vec3f[level2VertexCount][level2VertexCount] colors;
    ushort[level2QuadCount*level2QuadCount*6] indices;

    SectorNum center;
    SectorNum snapCenter;

    HeightSheets heightSheets;
    WorldMap worldMap;
    WorldState worldState;


    this(HeightSheets _heightSheets) {
        heightSheets = _heightSheets;
        worldMap = heightSheets.worldMap;
        worldState = heightSheets.worldState;
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
    }

    void buildHeightmap(SectorNum center) {
        // Build 10x10 sectors of level1-data (1 square kilometer)
        // That is (10*4+1)x(10*4+1) vertices
        //Dont be surprised if it doesnt!


        //Snap to every 4'th sector. Dont update unless!
        //4 comes from that a quad in level3 is 4 sectors big,
        // so we snap to every 4'th sector, yeah.
        auto snapCenter = SectorXYNum(snapV(center.value.v2, 4)).getSectorNum(center.value.z);
        this.snapCenter = snapCenter;
        this.center = center;

        vec3f centerTp = center.toTilePos.value.convert!float;

        SectorXYNum startSect = SectorXYNum(SectorXYNum(snapCenter).value - vec2i(level2SectorCount/2,level2SectorCount/2));

        vec2i baseTp = startSect.getTileXYPos().value;

        foreach(y ; 0 .. level2VertexCount) {
            foreach(x ; 0 .. level2VertexCount) {
                vec2i tp = baseTp + vec2i(level2SampleDistance) * vec2i(x, y);
                float X = cast(float) tp.x;
                float Y = cast(float) tp.y;
                float Z;
                if(x == 0 || x == level2QuadCount || y == 0 || y == level2QuadCount) {
                    Z = worldMap.getApproxHeight(TileXYPos(tp), 3);
                } else {
                    Z = worldMap.getApproxHeight(TileXYPos(tp), 2);
                }
                vertices[y][x].set(X,Y,Z);
                vertices[y][x] -= centerTp;
                colors[y][x] = worldMap.isInsideWorld(TileXYPos(tp).toTilePos(0)) ? vec3f(0.4) : vec3f(0.8, 0.1, 0.1);
            }
        }

        indices[] = 0;
        foreach(y ; 0 .. level2QuadCount) {
            foreach(x ; 0 .. level2QuadCount) {
                auto quadNum = vec2i(x, y);
                if( !shouldMakeHeightSheet(quadNum)) {
                    continue;
                }

                int base = 6*(level2QuadCount*y+x);
                indices[base + 1] = cast(ushort)(level2VertexCount * (y + 0) + x + 0);
                indices[base + 0] = cast(ushort)(level2VertexCount * (y + 1) + x + 0);
                indices[base + 2] = cast(ushort)(level2VertexCount * (y + 0) + x + 1);

                indices[base + 4] = cast(ushort)(level2VertexCount * (y + 1) + x + 0);
                indices[base + 3] = cast(ushort)(level2VertexCount * (y + 1) + x + 1);
                indices[base + 5] = cast(ushort)(level2VertexCount * (y + 0) + x + 1);
            }
        }

        float get(int x, int y) {
            if(x < 0 || x > level2QuadCount || y < 0 || y > level2QuadCount) {
                //Should make it so that it returns an extrapolated version, or something? dnot care so much myself :P
                x = x < 0 ? 0 : x;
                x = x > level2QuadCount ? level2QuadCount : x;
                y = y < 0 ? 0 : y;
                y = y > level2QuadCount ? level2QuadCount : y;
                return vertices[y][x].z;
            } else {
                return vertices[y][x].z;
            }
        }

        foreach(y ; 0 .. level2VertexCount) { 
            foreach(x ; 0 .. level2VertexCount) {

                float Xn = get(x-1, y  );
                float Xp = get(x+1, y  );
                float c  = get(x  , y  );
                float Yn = get(x  , y-1);
                float Yp = get(x  , y+1);


                vec3f Nx1 = vec3f(Xn - c, 0.0f, level2SampleDistance);
                vec3f Nx2 = vec3f(c - Xp, 0.0f, level2SampleDistance);
                vec3f Ny1 = vec3f(0.0f, Yn - c, level2SampleDistance);
                vec3f Ny2 = vec3f(0.0f, c - Yp, level2SampleDistance);

                normals[y][x] = (Nx1 + Nx2 + Ny1 + Ny2).normalize();
            }
        }


        if(vertVBO == 0) {
            glGenBuffers(1, &vertVBO); glError();
            glBindBuffer(GL_ARRAY_BUFFER, vertVBO);
            glBufferData(GL_ARRAY_BUFFER, vertices.sizeof, vertices.ptr, GL_STATIC_DRAW);
        } else {
            glBindBuffer(GL_ARRAY_BUFFER, vertVBO);
            glBufferSubData(GL_ARRAY_BUFFER, 0, vertices.sizeof, vertices.ptr);
        }

        if(normVBO == 0) {
            glGenBuffers(1, &normVBO); glError();
            glBindBuffer(GL_ARRAY_BUFFER, normVBO);
            glBufferData(GL_ARRAY_BUFFER, normals.sizeof, normals.ptr, GL_STATIC_DRAW);
        } else {
            glBindBuffer(GL_ARRAY_BUFFER, normVBO);
            glBufferSubData(GL_ARRAY_BUFFER, 0, normals.sizeof, normals .ptr);
        }

        if(colorVBO == 0) {
            glGenBuffers(1, &colorVBO ); glError();
            glBindBuffer(GL_ARRAY_BUFFER, colorVBO );
            glBufferData(GL_ARRAY_BUFFER, colors.sizeof, colors.ptr, GL_STATIC_DRAW);
        } else {
            glBindBuffer(GL_ARRAY_BUFFER, colorVBO );
            glBufferSubData(GL_ARRAY_BUFFER, 0, colors.sizeof, colors.ptr);
        }

        if(idxVBO == 0) {
            glGenBuffers(1, &idxVBO); glError();
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, idxVBO);
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.sizeof, indices.ptr, GL_STATIC_DRAW);
        } else {
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, idxVBO);
            glBufferSubData(GL_ELEMENT_ARRAY_BUFFER, 0, indices.sizeof, indices.ptr);
        }
    }

    void render(Camera camera) {

        glBindBuffer(GL_ARRAY_BUFFER, vertVBO); glError();
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, cast(void*) 0); glError();

        glBindBuffer(GL_ARRAY_BUFFER, normVBO); glError();
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, cast(void*) 0); glError();

        glBindBuffer(GL_ARRAY_BUFFER, colorVBO); glError();
        glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, cast(void*) 0); glError();

        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, idxVBO);

        glDrawElements(GL_TRIANGLES, level2QuadCount*level2QuadCount*6, GL_UNSIGNED_SHORT, cast(void*) 0);

    }

    bool shouldMakeHeightSheet(vec2i quadNum) {
        //Ignore the sectors in the middle. We have level1&0 there, possibly tiles as well.
        quadNum -= vec2i(level2QuadCount/2);
        quadNum = quadNum * 2 + vec2i(1);

        immutable numCoveringQuads = level1SectorCount * level2QuadCount / level2SectorCount;

        if(abs(quadNum.x) >= numCoveringQuads) return true;
        if(abs(quadNum.y) >= numCoveringQuads) return true;
        return false;
    }
}

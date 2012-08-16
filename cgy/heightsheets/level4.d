module heightsheets.level4;

import std.algorithm;
import std.stdio;
import std.math;

import heightsheets.heightsheets;
//import heightsheets.level2;

import graphics.camera;
import graphics.ogl;
import graphics.shader;
import modules.module_;
import worldgen.maps;
import worldstate.worldstate;
import util.util;

immutable int level4SectorCount = 1024;

immutable int level4QuadCount = 64;
immutable int level4VertexCount = level4QuadCount+1;


final class Level4Sheet {
    uint vertVBO;
    uint normVBO;
    uint colorVBO;
    uint idxVBO;

    vec3f[level4VertexCount][level4VertexCount] vertices;
    vec3f[level4VertexCount][level4VertexCount] normals;
    vec3f[level4VertexCount][level4VertexCount] colors;
    ushort[level4QuadCount*level4QuadCount*6] indices;

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

        auto snapCenter = SectorXYNum((SectorXYNum(center).value/64 )*64).getSectorNum(center.value.Z);
        this.snapCenter = snapCenter;
        this.center = center;

        vec3f centerTp = center.toTilePos.value.convert!float;

        SectorXYNum startSect = SectorXYNum(SectorXYNum(snapCenter).value - vec2i(level4SectorCount/2,level4SectorCount/2));

        vec2i baseTp = startSect.getTileXYPos().value;

        foreach(y ; 0 .. level4VertexCount) {
            foreach(x ; 0 .. level4VertexCount) {
                vec2i tp = baseTp + vec2i(2048) * vec2i(x, y);
                float X = cast(float) tp.X;
                float Y = cast(float) tp.Y;
                float Z;
                if(x == 0 || x == level4QuadCount || y == 0 || y == level4QuadCount) {
                    Z = cast(float) worldMap.getValueInterpolated(5, TileXYPos(tp));
                } else {
                    Z = cast(float) worldMap.getValueRaw(4, tp);
                }
                vertices[y][x].set(X,Y,Z);
                vertices[y][x] -= centerTp;
                colors[y][x] = worldMap.getAreaColor(TileXYPos(tp));
            }
        }

        indices[] = 0;
        foreach(y ; 0 .. level4QuadCount) {
            foreach(x ; 0 .. level4QuadCount) {
                if( !shouldMakeHeightSheet(vec2i(x,y))) {
                    continue;
                }

                int base = 6*(level4QuadCount*y+x);
                indices[base + 1] = cast(ushort)(level4VertexCount * (y + 0) + x + 0);
                indices[base + 0] = cast(ushort)(level4VertexCount * (y + 1) + x + 0);
                indices[base + 2] = cast(ushort)(level4VertexCount * (y + 0) + x + 1);

                indices[base + 4] = cast(ushort)(level4VertexCount * (y + 1) + x + 0);
                indices[base + 3] = cast(ushort)(level4VertexCount * (y + 1) + x + 1);
                indices[base + 5] = cast(ushort)(level4VertexCount * (y + 0) + x + 1);
            }
        }

        float get(int x, int y) {
            if(x < 0 || x > level4QuadCount || y < 0 || y > level4QuadCount) {
                //Should make it so that it returns an extrapolated version, or something? dnot care so much myself :P
                x = x < 0 ? 0 : x;
                x = x > level4QuadCount ? level4QuadCount : x;
                y = y < 0 ? 0 : y;
                y = y > level4QuadCount ? level4QuadCount : y;
                return vertices[y][x].Z;
            } else {
                return vertices[y][x].Z;
            }
        }

        foreach(y ; 0 .. level4VertexCount) { 
            foreach(x ; 0 .. level4VertexCount) {

                float Xn = get(x-1, y  );
                float Xp = get(x+1, y  );
                float c  = get(x  , y  );
                float Yn = get(x  , y-1);
                float Yp = get(x  , y+1);


                vec3f Nx1 = vec3f(Xn - c, 0.0f, 2048.0f);
                vec3f Nx2 = vec3f(c - Xp, 0.0f, 2048.0f);
                vec3f Ny1 = vec3f(0.0f, Yn - c, 2048.0f);
                vec3f Ny2 = vec3f(0.0f, c - Yp, 2048.0f);

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

        glDrawElements(GL_TRIANGLES, level4QuadCount*level4QuadCount*6, GL_UNSIGNED_SHORT, cast(void*) 0);

    }


    bool shouldMakeHeightSheet(vec2i quadNum) {

        //This is the center of level2
        auto level3Center = (SectorXYNum(center).value/16)*16;

        quadNum = quadNum + SectorXYNum(snapCenter).value/16 - level3Center/16 - vec2i(level4QuadCount/2);
        //As expected this makes a line of quads per axis intersect. But it doesn't really matter ;P
        if(abs(quadNum.X) >= 8) return true;
        if(abs(quadNum.Y) >= 8) return true;

        return false;
    }

    /*
    bool shouldMakeHeightSheet(vec2i num) {
        //Ignore the sectors in the middle. We have level1&0 there, possibly tiles as well.
        num -= vec2i(level3QuadCount/2);
        if(abs(num.X) >= 8) return true;
        if(abs(num.Y) >= 8) return true;
        return false;
    }
    */
}

module heightsheets.level1;

import std.algorithm;
import std.stdio;

import heightsheets.heightsheets;
import heightsheets.level0;

import graphics.camera;
import graphics.ogl;
import graphics.shader;
import modules.module_;
import worldgen.maps;
import worldstate.worldstate;
import util.util;


enum int level1SectorCount = 16;
enum int level1QuadCount = 4*level1SectorCount;

final class Level1Sheet {
    uint vertVBO;
    uint normVBO;
    uint colorVBO;
    uint idxVBO;

    //This is for level1-stuff. yeah.
    vec3f[level1QuadCount+1][level1QuadCount+1] vertices; //lol 20k of vertex data on stack
    vec3f[level1QuadCount+1][level1QuadCount+1] normals;  //Another 20k! will it blend?
    vec3f[level1QuadCount+1][level1QuadCount+1] colors;   // EVEN MORE! WILL TEH STACK CORPPTU?
    float sectorMin[level1SectorCount*level1SectorCount];
    float sectorMax[level1SectorCount*level1SectorCount];
    ushort[level1QuadCount*level1QuadCount*6] indices;

    SectorNum center;
    bool[level1SectorCount][level1SectorCount] loaded;

    HeightSheets heightSheets;
    WorldMap worldMap;
    WorldState worldState;

    Level0Sheet level0;


    this(HeightSheets _heightSheets) {
        heightSheets = _heightSheets;
        worldMap = heightSheets.worldMap;
        worldState = heightSheets.worldState;
        level0 = new Level0Sheet(this);
    }

    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {
        level0.destroy();
        destroyed = true;
        //Should also destroy any opengl stuff?
        //Or not?
    }

    void init() {
        level0.init();
    }

    void buildHeightmap(SectorNum center) {
        // Build level1SectorCountxlevel1SectorCount sectors of level1-data (1 square kilometer)
        // That is (level1SectorCount*4+1)x(level1SectorCount*4+1) vertices
        //Dont be surprised if it doesnt!


        this.center = center;
        vec3f centerTp = center.toTilePos.value.convert!float;

        SectorXYNum startSect = SectorXYNum(SectorXYNum(center).value - vec2i(8,8));

        vec2i baseTp = startSect.getTileXYPos().value;

        sectorMin[] = float.max;
        sectorMax[] = -float.max;

        foreach(y ; 0 .. level1QuadCount+1) {
            foreach(x ; 0 .. level1QuadCount+1) {
                vec2i tp = baseTp + vec2i(32) * vec2i(x, y);
                float X = cast(float) tp.X;
                float Y = cast(float) tp.Y;
                float Z;
                if(x == 0 || x == level1QuadCount || y == 0 || y == level1QuadCount) {
                    Z = cast(float) worldMap.getValueInterpolated(2, TileXYPos(tp));
                } else {
                    Z = cast(float) worldMap.getValueRaw(1, tp);
                }
                vertices[y][x].set(X,Y,Z);
                vertices[y][x] -= centerTp;
                pragma(msg, "colors[y][x] = worldMap.getBiomeColor(tp);");
            }
        }

        foreach(y ; 0 .. level1SectorCount) {
            foreach(x ; 0 .. level1SectorCount) {
                foreach(dx ; 0 .. 5) {
                    foreach(dy ; 0 .. 5) {
                        sectorMin[level1SectorCount * y + x] = min(sectorMin[level1SectorCount * y + x], vertices[y*4+dx][x*4+dy].Z);
                        sectorMax[level1SectorCount * y + x] = max(sectorMax[level1SectorCount * y + x], vertices[y*4+dx][x*4+dy].Z);
                    }
                }
            }
        }

        indices[] = 0;
        foreach(sectY ; 0 .. level1SectorCount) {
            foreach(sectX ; 0 .. level1SectorCount) {
                if( !shouldMakeHeightSheet(vec2i(sectX, sectY))) {
                    loaded[sectY][sectX] = false;
                    continue;
                }
                loaded[sectY][sectX] = true;
                foreach(dy ; 0 .. 4) {
                    auto y = sectY * 4 + dy;
                    foreach(dx ; 0 .. 4) {
                        auto x = sectX * 4 + dx;
                        vec2i tp = baseTp + vec2i(32) * vec2i(x, y);
                        int base = 6*(level1QuadCount*y+x);

                        indices[base + 1] = cast(ushort)((level1QuadCount+1) * (y + 0) + x + 0);
                        indices[base + 0] = cast(ushort)((level1QuadCount+1) * (y + 1) + x + 0);
                        indices[base + 2] = cast(ushort)((level1QuadCount+1) * (y + 0) + x + 1);

                        indices[base + 4] = cast(ushort)((level1QuadCount+1) * (y + 1) + x + 0);
                        indices[base + 3] = cast(ushort)((level1QuadCount+1) * (y + 1) + x + 1);
                        indices[base + 5] = cast(ushort)((level1QuadCount+1) * (y + 0) + x + 1);
                    }
                }
            }
        }

        float get(int x, int y) {
            if(x < 0 || x > level1QuadCount || y < 0 || y > level1QuadCount) {
                //Should make it so that it returns an extrapolated version, or something? dnot care so much myself :P
                x = x < 0 ? 0 : x;
                x = x > level1QuadCount ? level1QuadCount : x;
                y = y < 0 ? 0 : y;
                y = y > level1QuadCount ? level1QuadCount : y;
                return vertices[y][x].Z;
            } else {
                return vertices[y][x].Z;
            }
        }

        foreach(y ; 0 .. level1QuadCount+1) { 
            foreach(x ; 0 .. level1QuadCount+1) {

                float Xn = get(x-1, y  );
                float Xp = get(x+1, y  );
                float c  = get(x  , y  );
                float Yn = get(x  , y-1);
                float Yp = get(x  , y+1);


                vec3f Nx1 = vec3f(Xn - c, 0.0f, 32.0f);
                vec3f Nx2 = vec3f(c - Xp, 0.0f, 32.0f);
                vec3f Ny1 = vec3f(0.0f, Yn - c, 32.0f);
                vec3f Ny2 = vec3f(0.0f, c - Yp, 32.0f);

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
        level0.buildHeightmap(center);
    }

    void render(Camera camera) {
        glBindBuffer(GL_ARRAY_BUFFER, vertVBO); glError();
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, cast(void*) 0); glError();

        glBindBuffer(GL_ARRAY_BUFFER, normVBO); glError();
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, cast(void*) 0); glError();

        glBindBuffer(GL_ARRAY_BUFFER, colorVBO); glError();
        glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, cast(void*) 0); glError();

        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, idxVBO);

        glDrawElements(GL_TRIANGLES, level1QuadCount*level1QuadCount*6, GL_UNSIGNED_SHORT, cast(void*) 0);

        level0.render(camera);
    }

    //Indexed [0..level1SectorCount] in x,y
    //Loops over the range of sectors that the heightsheet covers at a xy-secnum,
    //checks if it is part of the current world, if not then we are free to make heightsheets.
    bool shouldMakeHeightSheet(vec2i sectorNum) {

        double maxZ = sectorMax[sectorNum.Y * level1SectorCount + sectorNum.X] + center.toTilePos.value.Z;
        double minZ = sectorMin[sectorNum.Y * level1SectorCount + sectorNum.X] + center.toTilePos.value.Z;

        SectorXYNum startSect = SectorXYNum(SectorXYNum(center).value - vec2i(8,8));
        SectorXYNum thisSect = SectorXYNum(startSect.value + sectorNum);
        TileXYPos tp = thisSect.getTileXYPos;
        TilePos maxTP = tp.toTilePos(cast(int)maxZ);
        TilePos minTP = tp.toTilePos(cast(int)minZ);

        auto maxSector = maxTP.getSectorNum();
        auto minSector = minTP.getSectorNum();
        foreach(z ; minSector.value.Z .. maxSector.value.Z+1) {
            auto testNum = thisSect.getSectorNum(z);
            if(worldState.isActiveSector(testNum)) {
                if(worldState.isAirSector(testNum)) continue;
                return false;
            }
        }
        return true;
    }

}

module heightsheets;

/+
[14:35:38] <@Luben> vi borde ha ett bättre namn än heightmap
[14:35:59] <@Luben> för att särskilja på arrayer med punkvärden, och polygontäcke för sådana
[14:37:00] <@Luben> har ni något förslag eller tanke, plol Fungu?
[14:37:09] <@plol> heightsheet
[14:37:11] <@Luben> och vill du ha te Fungu, ?
[14:37:18] <@Luben> lol, heightsheet funkar :P
[14:37:37] <Fungu> jkla
[14:37:41] <@plol> JKLA
[14:37:47] <@Luben> ok JklA
[14:37:49] <@Luben> kompromiss där?
+/

import std.algorithm;
import std.stdio;

import graphics.camera;
import graphics.ogl;
import graphics.shader;
import modules.module_;
import world.world;
import worldgen.newgen;
import util.util;

final class HeightSheets : Module, WorldListener {
    


    World world;
    LayerManager layerManager;

    alias ShaderProgram!("offset", "VP") HeightSheetsShader;
    HeightSheetsShader shader;


    this(World _world) {
        world = _world;
        layerManager = world.worldGen.getLayerManager();
        world.addListener(this);

    }

    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {
        world.removeListener(this);
        destroyed = true;
    }

    void init() {
        /+_+/
        shader = new HeightSheetsShader("shaders/HeightSheets.vert", "shaders/HeightSheets.frag");
        shader.bindAttribLocation(0, "position");
        shader.bindAttribLocation(1, "normal");
        shader.bindAttribLocation(2, "color");
        shader.link();
        shader.offset      = shader.getUniformLocation("offset");
        shader.VP          = shader.getUniformLocation("VP");

    }

    uint vertVBO;
    uint normVBO;
    uint colorVBO;
    uint idxVBO;

    //This is for level1-stuff. yeah.
    vec3f[41][41] vertices; //lol 20k of vertex data on stack
    vec3f[41][41] normals;  //Another 20k! will it blend?
    vec3f[41][41] colors;   // EVEN MORE! WILL TEH STACK CORPPTU?
    float sectorMin[100];
    float sectorMax[100];
    ushort[40*40*6] indices;

    void buildHeightmap(SectorNum center) {
        // Build 10x10 sectors of level1-data (1 square kilometer)
        // That is (10*4+1)x(10*4+1) vertices
        //Dont be surprised if it doesnt!


        this.center = center;
        vec3f centerTp = center.toTilePos.value.convert!float;

        SectorXYNum startSect = SectorXYNum(SectorXYNum(center).value - vec2i(5,5));

        vec2i baseTp = startSect.getTileXYPos().value;

        sectorMin[] = float.max;
        sectorMax[] = -float.max;

        foreach(y ; 0 .. 41) {
            foreach(x ; 0 .. 41) {
                vec2i tp = baseTp + vec2i(32) * vec2i(x, y);
                float X = cast(float) tp.X;
                float Y = cast(float) tp.Y;
                float Z;
                if(x == 0 || x == 40 || y == 0 || y == 40) {
                    Z = cast(float) layerManager.getValueInterpolated(2, TileXYPos(tp));
                } else {
                    Z = cast(float) layerManager.getValueRaw(1, tp);
                }
                vertices[y][x].set(X,Y,Z);
                vertices[y][x] -= centerTp;
                colors[y][x] = layerManager.getBiomeColor(tp);
            }
        }

        foreach(y ; 0 .. 10) {
            foreach(x ; 0 .. 10) {
                foreach(dx ; 0 .. 5) {
                    foreach(dy ; 0 .. 5) {
                        sectorMin[10 * y + x] = min(sectorMin[10 * y + x], vertices[y*4+dx][x*4+dy].Z);
                        sectorMax[10 * y + x] = max(sectorMax[10 * y + x], vertices[y*4+dx][x*4+dy].Z);
                    }
                }
            }
        }

        indices[] = 0;
        foreach(sectY ; 0 .. 10) {
            foreach(sectX ; 0 .. 10) {
                if( !shouldMakeHeightSheet(vec2i(sectX, sectY))) {
                    loaded[sectX][sectY] = false;
                    continue;
                }
                loaded[sectX][sectY] = true;
                foreach(dy ; 0 .. 4) {
                    auto y = sectY * 4 + dy;
                    foreach(dx ; 0 .. 4) {
                        auto x = sectX * 4 + dx;
                        vec2i tp = baseTp + vec2i(32) * vec2i(x, y);
                        int base = 6*(40*y+x);

                        indices[base + 1] = cast(ushort)(41 * (y + 0) + x + 0);
                        indices[base + 0] = cast(ushort)(41 * (y + 1) + x + 0);
                        indices[base + 2] = cast(ushort)(41 * (y + 0) + x + 1);

                        indices[base + 4] = cast(ushort)(41 * (y + 1) + x + 0);
                        indices[base + 3] = cast(ushort)(41 * (y + 1) + x + 1);
                        indices[base + 5] = cast(ushort)(41 * (y + 0) + x + 1);
                    }
                }
            }
        }

        float get(int x, int y) {
            if(x < 0 || x > 40 || y < 0 || y > 40) {
                //Should make it so that it returns an extrapolated version, or something? dnot care so much myself :P
                x = x < 0 ? 0 : x;
                x = x > 40 ? 40 : x;
                y = y < 0 ? 0 : y;
                y = y > 40 ? 40 : y;
                return vertices[y][x].Z;
            } else {
                return vertices[y][x].Z;
            }
        }

        foreach(y ; 0 .. 41) { 
            foreach(x ; 0 .. 41) {

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
    }

    SectorNum center;
    bool started = false;

    SectorNum[] addBack;
    SectorNum[] removeList;
    bool[10][10] loaded;

    //Indexed [0..10] in x,y
    //Loops over the range of sectors that the heightsheet covers at a xy-secnum,
    //checks if it is part of the current world, if not then we are free to make heightsheets.
    bool shouldMakeHeightSheet(vec2i sectorNum) {

        double maxZ = sectorMax[sectorNum.Y * 10 + sectorNum.X] + center.toTilePos.value.Z;
        double minZ = sectorMin[sectorNum.Y * 10 + sectorNum.X] + center.toTilePos.value.Z;

        SectorXYNum startSect = SectorXYNum(SectorXYNum(center).value - vec2i(5,5));
        SectorXYNum thisSect = SectorXYNum(startSect.value + sectorNum);
        TileXYPos tp = thisSect.getTileXYPos;
        TilePos maxTP = tp.toTilePos(cast(int)maxZ);
        TilePos minTP = tp.toTilePos(cast(int)minZ);

        auto maxSector = maxTP.getSectorNum();
        auto minSector = minTP.getSectorNum();
        foreach(z ; minSector.value.Z .. maxSector.value.Z+1) {
            auto testNum = thisSect.getSectorNum(z);
            if(world.isActiveSector(testNum)) {
                if(world.isAirSector(testNum)) continue;
                return false;
            }
        }
        return true;
    }

    void addParts() {
        if(addBack.length == 0 || idxVBO == 0) return;
        synchronized(this) {
            bool updated = false;
            SectorXYNum startSect = SectorXYNum(SectorXYNum(center).value - vec2i(5,5));
            foreach(sect ; addBack) {
                auto localId = SectorXYNum(sect).value - startSect.value;
                if(localId.X < 0 || localId.X >= 10 || localId.Y < 0 || localId.Y >= 10) continue;
                if(loaded[localId.Y][localId.X]) continue;
                if(! shouldMakeHeightSheet(localId)) continue;
                updated = true;
                loaded[localId.Y][localId.X] = true;

                foreach(Y ; 0 .. 4) {
                    foreach(X ; 0 .. 4) {
                        int x = X + localId.X * 4;
                        int y = Y + localId.Y * 4;
                        int newBaseIdx = 6*(40*y + x);
                        indices[newBaseIdx + 1] = cast(ushort)(41 * (y + 0) + x + 0);
                        indices[newBaseIdx + 0] = cast(ushort)(41 * (y + 1) + x + 0);
                        indices[newBaseIdx + 2] = cast(ushort)(41 * (y + 0) + x + 1);

                        indices[newBaseIdx + 4] = cast(ushort)(41 * (y + 1) + x + 0);
                        indices[newBaseIdx + 3] = cast(ushort)(41 * (y + 1) + x + 1);
                        indices[newBaseIdx + 5] = cast(ushort)(41 * (y + 0) + x + 1);

                    }
                }
            }
            addBack = null;
            if(updated) {
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, idxVBO);
                glBufferSubData(GL_ELEMENT_ARRAY_BUFFER, 0, indices.sizeof, indices.ptr);
            }
        }
    }

    void removeParts() {
        if(removeList.length == 0 || idxVBO == 0) return;
        synchronized(this) {
            bool updated = false;
            SectorXYNum startSect = SectorXYNum(SectorXYNum(center).value - vec2i(5,5));
            vec2i baseTp = startSect.getTileXYPos().value;

            foreach(sect ; removeList) {
                auto localId = SectorXYNum(sect).value - startSect.value;
                if(localId.X < 0 || localId.X >= 10 || localId.Y < 0 || localId.Y >= 10) continue;
                if(!loaded[localId.Y][localId.X]) continue;

                auto bottom = sect.toTilePos().value.Z;
                auto top = bottom + SectorSize.z;
                if(bottom > sectorMax[localId.Y * 10 + localId.X]) continue;
                if(top < sectorMin[localId.Y * 10 + localId.X]) continue;
                updated = true;
                loaded[localId.Y][localId.X] = false;

                foreach(y ; 0 .. 4) {
                    int newBaseIdx = 6*(40*(localId.Y*4 + y) + localId.X*4);
                    indices[newBaseIdx .. newBaseIdx + 6*4] = 0;
                }
            }
            removeList = null;
            if(updated) {
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, idxVBO);
                glBufferSubData(GL_ELEMENT_ARRAY_BUFFER, 0, indices.sizeof, indices.ptr);
            }
        }
    }

    void render(Camera camera) {

        TilePos camTP = TilePos(camera.getPosition().convert!int);
        SectorNum camSector = camTP.getSectorNum;
        if(!started || (camSector.value-center.value).getLengthSQ() > 0) {
            started = true;
            buildHeightmap(camSector);
        }
        if(addBack.length > 0) {
            addParts();
        }

        if(removeList.length > 0) {
            removeParts();
        }


        shader.use();
        vec3f toCam = (center.toTilePos.value.convert!double - camera.getPosition()).convert!float;
        shader.setUniform(shader.offset, toCam);

        auto VP = camera.getProjectionMatrix() * camera.getTargetMatrix();
        shader.setUniform(shader.VP, VP);

        glEnableVertexAttribArray(0); glError();
        glEnableVertexAttribArray(1); glError();
        glEnableVertexAttribArray(2); glError();

        glBindBuffer(GL_ARRAY_BUFFER, vertVBO); glError();
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, cast(void*) 0); glError();

        glBindBuffer(GL_ARRAY_BUFFER, normVBO); glError();
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, cast(void*) 0); glError();

        glBindBuffer(GL_ARRAY_BUFFER, colorVBO); glError();
        glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, cast(void*) 0); glError();

        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, idxVBO);

        glDrawElements(GL_TRIANGLES, 40*40*6, GL_UNSIGNED_SHORT, cast(void*) 0);

        glDisableVertexAttribArray(0); glError();
        glDisableVertexAttribArray(1); glError();
        glDisableVertexAttribArray(2); glError();

        shader.use(false);

    }

    override void serializeModule() { }

    override void deserializeModule() { }

    override void update(World world, Scheduler scheduler) { // Module interface
        //If work left
        //Queue a bit, or all!

    }


    void onAddUnit(SectorNum, Unit) { }
	void onAddEntity(SectorNum, Entity) { }
    void onTileChange(TilePos tilePos) { }

    void onBuildGeometry(SectorNum sectorNum) {
        synchronized(this) {
            removeList ~= sectorNum;
        }
    }
    void onUpdateGeometry(TilePos tilePos) { }

    void onSectorLoad(SectorNum sectorNum) {
        synchronized(this) {
            removeList ~= sectorNum;
        }
    }
    void onSectorUnload(SectorNum sectorNum) {
        synchronized(this) {
            addBack ~= sectorNum;
        }
    }

}

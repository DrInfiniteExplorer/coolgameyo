module jkla;

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

import std.stdio;

import graphics.camera;
import graphics.ogl;
import graphics.shader;
import modules.module_;
import world.world;
import worldgen.newgen;
import util.util;

final class JklA : Module, WorldListener {
    


    World world;
    LayerManager layerManager;

    alias ShaderProgram!("offset", "VP") JklAShader;
    JklAShader shader;


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
        shader = new JklAShader("shaders/JklA.vert", "shaders/JklA.frag");
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
    ushort[40*40*6] indices;

    void buildHeightmap(SectorNum center) {
        // Build 10x10 sectors of level1-data (1 square kilometer)
        // That is (10*4+1)x(10*4+1) vertices
        //Dont be surprised if it doesnt!

        vec3f centerTp = center.toTilePos.value.convert!float;

        SectorXYNum startSect = SectorXYNum(SectorXYNum(center).value - vec2i(5,5));

        vec2i baseTp = startSect.getTileXYPos().value;

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

        foreach(y ; 0 .. 40) {
            foreach(x ; 0 .. 40) {
                vec2i tp = baseTp + vec2i(32) * vec2i(x, y);
                int base = 6*(40*y+x);
                if( TileXYPos(tp).getSectorXYNum().value in dontLoad) {
                    indices[base .. base+6] = 0;
                    continue;
                }

                indices[base + 1] = cast(ushort)(41 * (y + 0) + x + 0);
                indices[base + 0] = cast(ushort)(41 * (y + 1) + x + 0);
                indices[base + 2] = cast(ushort)(41 * (y + 0) + x + 1);

                indices[base + 4] = cast(ushort)(41 * (y + 1) + x + 0);
                indices[base + 3] = cast(ushort)(41 * (y + 1) + x + 1);
                indices[base + 5] = cast(ushort)(41 * (y + 0) + x + 1);
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

        this.center = center;
    }

    SectorNum center;
    bool started = false;

    bool dontLoad[vec2i];
    vec2i[] removeList;
    vec2i[] addBack;

    void addParts() {
        if(addBack.length == 0 || idxVBO == 0) return;
        synchronized(this) {
            SectorXYNum startSect = SectorXYNum(SectorXYNum(center).value - vec2i(5,5));
            vec2i baseTp = startSect.getTileXYPos().value;
            foreach(sect ; removeList) {
                auto localId = sect - startSect.value;
                if(sect.X < 0 || sect.X >= 10 || sect.Y < 0 || sect.Y >= 10) continue;
                int baseIdx = 6*4*(10*sect.Y + sect.X);
                foreach(Y ; 0 .. 4) {
                    int newBaseIdx = baseIdx + 4*6*10*Y;
                    foreach(X ; 0 .. 4) {
                        int x = X * 4;
                        int y = Y * 4;
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
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, idxVBO);
            glBufferSubData(GL_ELEMENT_ARRAY_BUFFER, 0, indices.sizeof, indices.ptr);

        }
    }

    void removeParts() {
        if(removeList.length == 0 || idxVBO == 0) return;
        synchronized(this) {
            SectorXYNum startSect = SectorXYNum(SectorXYNum(center).value - vec2i(5,5));
            vec2i baseTp = startSect.getTileXYPos().value;

            foreach(sect ; removeList) {
                auto localId = sect - startSect.value;
                if(sect.X < 0 || sect.X >= 10 || sect.Y < 0 || sect.Y >= 10) continue;
                int baseIdx = 6*4*(4*sect.Y + sect.X);
                foreach(y ; 0 .. 4) {
                    int newBaseIdx = baseIdx + 4*6*10*y;
                    indices[newBaseIdx .. newBaseIdx + 6*4] = 0;
                }
            }
            removeList = null;
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, idxVBO);
            glBufferSubData(GL_ELEMENT_ARRAY_BUFFER, 0, indices.sizeof, indices.ptr);
        }
    }

    void render(Camera camera) {

        TilePos camTP = TilePos(camera.getPosition().convert!int);
        SectorNum camSector = camTP.getSectorNum;
        if(!started || (camSector.value-center.value).getLengthSQ() > 2) {
            started = true;
            buildHeightmap(camSector);
        }
        if(removeList.length > 0) {
            removeParts();
        }
        if(addBack.length > 0) {
            addParts();
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
        auto val = SectorXYNum(sectorNum).value;
        if (val !in dontLoad) {
            synchronized(this) {
                removeList ~= val;
            }
        }
        dontLoad[val] = true;
    }
    void onUpdateGeometry(TilePos tilePos) { }

    void onSectorLoad(SectorNum sectorNum) {
        auto val = SectorXYNum(sectorNum).value;
        dontLoad[val] = true;
    }
    void onSectorUnload(SectorNum sectorNum) {
        auto val = SectorXYNum(sectorNum).value;
        dontLoad.remove(val);
        if(val in dontLoad) {
            synchronized(this) {
                addBack ~= val;
            }
        }
    }

}

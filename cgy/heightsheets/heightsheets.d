module heightsheets.heightsheets;

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

import heightsheets.level1;
import heightsheets.level2;
import heightsheets.level3;
import heightsheets.level4;
import heightsheets.level5;

import graphics.camera;
import graphics.ogl;
import graphics.shader;
import modules.module_;
import worldgen.maps;
import worldstate.worldstate;
import util.util;

final class HeightSheets : Module, WorldStateListener {


    WorldMap worldMap;
    WorldState worldState;
    Level1Sheet level1;
    Level2Sheet level2;
    Level3Sheet level3;
    Level4Sheet level4;
    Level5Sheet level5;

    alias ShaderProgram!("offset", "VP", "sunDir") HeightSheetsShader;
    HeightSheetsShader shader;


    this(WorldMap _maps, WorldState _world) {
        worldMap = _maps;
        worldState = _world;
        worldState.addListener(this);
        level1 = new Level1Sheet(this);
        level2 = new Level2Sheet(this);
        level3 = new Level3Sheet(this);
        level4 = new Level4Sheet(this);
        level5 = new Level5Sheet(this);
    }

    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {
        worldState.removeListener(this);
        level1.destroy();
        level2.destroy();
        level3.destroy();
        level4.destroy();
        level5.destroy();
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
        shader.sunDir      = shader.getUniformLocation("sunDir");

        level1.init();
        level2.init();
        level3.init();
        level4.init();
        level5.init();

    }



    SectorNum[] addBack;
    SectorNum[] removeList;
    bool started = false;
    SectorNum center;

    void addParts() {
        /*
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
        */
    }

    void removeParts() {
        /*
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
        */
    }

    void render(Camera camera) {
        if(camera.getPosition().getLengthSQ() == 0.0) return;

        TilePos camTP = TilePos(camera.getPosition().convert!int);
        SectorNum camSector = camTP.getSectorNum;

        if(!started || (camSector.value-center.value).getLengthSQ() > 0) {
            started = true;
            level1.buildHeightmap(camSector);
            
            level2.buildHeightmap(camSector);
            level3.buildHeightmap(camSector);
            level4.buildHeightmap(camSector);
            level5.buildHeightmap(camSector);
            center = camSector;
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

        auto sunDir = (worldState.getSunPosition() - camera.getPosition()).normalize().convert!float;
        shader.setUniform(shader.sunDir, sunDir);


        glEnableVertexAttribArray(0); glError();
        glEnableVertexAttribArray(1); glError();
        glEnableVertexAttribArray(2); glError();

        //16 mil...
        auto VP = camera.getProjectionMatrix(100.0f, 640_000.0f) * camera.getTargetMatrix();
        shader.setUniform(shader.VP, VP);

        level5.render(camera);

        level4.render(camera);

        level3.render(camera);

        level2.render(camera);
        glClear(GL_DEPTH_BUFFER_BIT);

        VP = camera.getProjectionMatrix() * camera.getTargetMatrix();
        shader.setUniform(shader.VP, VP);
        level1.render(camera);
        


        glDisableVertexAttribArray(0); glError();
        glDisableVertexAttribArray(1); glError();
        glDisableVertexAttribArray(2); glError();

        shader.use(false);

    }

    override void serializeModule() { }

    override void deserializeModule() { }

    override void update(WorldState world, Scheduler scheduler) { // Module interface
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

    override void onSectorLoad(SectorNum sectorNum) {
        synchronized(this) {
            removeList ~= sectorNum;
        }
    }
    override void onSectorUnload(SectorNum sectorNum) {
        synchronized(this) {
            addBack ~= sectorNum;
        }
    }

}

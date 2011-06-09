
module graphics.renderer;

import std.array;
import std.conv;
import std.exception;
import std.format;
import std.stdio;
import std.string;

import stolen.all;

import graphics.camera;
import graphics.misc;
import graphics.ogl;
import graphics.shader;
import graphics.texture;
import graphics.vbomaker;

import modules;
import world;
import scheduler;
import settings;
import unit;
import util;

//TODO: Make fix this, or make testcase and report it if not done already.
auto grTexCoordOffset = GRVertex.texcoord.offsetof;

class Renderer : Module {
    //TODO: Leave comment on what these members are use for in this class
    World world;
    Scheduler scheduler;
    VBOMaker vboMaker;
    Camera camera;

    TileTextureAtlas atlas;
    
    alias ShaderProgram!("offset", "VP", "atlas") WorldShaderProgram;
    alias ShaderProgram!("VP", "M", "color") DudeShaderProgram;

    WorldShaderProgram worldShader;
    DudeShaderProgram dudeShader;

    this(World w, Scheduler s, Camera c)
    {
        world = w;
        scheduler = s;
        camera = c;
        vboMaker = new VBOMaker(w, s, c);

        scheduler.registerModule(this);

        //Would be kewl if with templates and compile-time one could specify uniform names / attrib slot names
        //that with help of shaders where made into member variables / compile-time-lookup(attrib slot names)
        worldShader = new WorldShaderProgram("shaders/renderGR.vert", "shaders/renderGR.frag");
        worldShader.bindAttribLocation(0, "position");
        worldShader.bindAttribLocation(1, "texcoord");
        worldShader.link();
        worldShader.offset = worldShader.getUniformLocation("offset");
        worldShader.VP = worldShader.getUniformLocation("VP");
        worldShader.atlas = worldShader.getUniformLocation("atlas");
        worldShader.use();
        worldShader.setUniform(worldShader.atlas, 0); //Texture atlas will always reside in texture unit 0 yeaaaah

        dudeShader = new DudeShaderProgram("shaders/renderDude.vert", "shaders/renderDude.frag");
        dudeShader.bindAttribLocation(0, "position");
        dudeShader.link();
        dudeShader.VP = dudeShader.getUniformLocation("VP");
        dudeShader.M = dudeShader.getUniformLocation("M");
        dudeShader.color = dudeShader.getUniformLocation("color");

        createDudeModel();

  }

    //TODO: Eventually implement models, etc
    uint dudeVBO;
    void createDudeModel(){
        vec3f[] vertices;
        vertices ~= makeCube(vec3f(0.5, 0.5, 1), vec3f(0, 0, 0.5)); //Body, -.25, -.25, -.5 -> .25, .25, .5
        vertices ~= makeCube(vec3f(1, 1, 1), vec3f(0, 0, 1.5)); //Head, -.5, -.5, .5 -> .5, .5, 1.0
        glGenBuffers(1, &dudeVBO);
        glError();
        glBindBuffer(GL_ARRAY_BUFFER, dudeVBO);
        glError();
        glBufferData(GL_ARRAY_BUFFER, vertices.length*vec3f.sizeof, vertices.ptr, GL_STATIC_DRAW);
        glError();
    }

    void renderDude(Unit* unit, float tickTimeSoFar){
        auto M = matrix4();
        vec3d unitPos = unit.pos.value; //TODO: Subtract the camera position from the unit before rendering
        unitPos += tickTimeSoFar * unit.velocity;
        M.setTranslation(util.convert!float(unitPos));
        M.setRotationRadians(vec3f(0, 0, unit.rotation));
        dudeShader.setUniform(dudeShader.M, M);
        dudeShader.setUniform(dudeShader.color, vec3f(0, 0.7, 0)); //Color :p
        glBindBuffer(GL_ARRAY_BUFFER, dudeVBO);
        glError();
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, null /* offset in vbo */);
        glError();

        glDrawArrays(GL_QUADS, 0, 4*6*2 /*2 cubes */);
        glError();


        //TODO: Move to own function, make own shader or abstractify a "simpleshader"-thing to use.
        const bool RenderDudeAABB = false;
        static if(RenderDudeAABB == true){
            bool oldWireframe = setWireframe(true);

            //dudeShader.use(false);
            glBindBuffer(GL_ARRAY_BUFFER, 0);
            auto bb = unit.aabb;
            vec3d[8] edges;
            bb.getEdges(edges);

            glVertexAttribPointer(0, 3, GL_DOUBLE, GL_FALSE, vec3d.sizeof, edges.ptr);
            glError();
            M = matrix4(); //AABB is in world coordinates
            dudeShader.setUniform(dudeShader.b, M);
            dudeShader.setUniform(dudeShader.c, vec3f(0.8, 0.0, 0));
            immutable ubyte[] indices = [0, 1, 0, 4, 0, 2, 2, 6, 2, 3, 5, 1, 5, 4, 6, 2, 6, 4, 6, 7, 7, 5, 7, 3];
            glDrawElements(GL_LINES, indices.length, GL_UNSIGNED_BYTE, indices.ptr);
            glError();
            //dudeShader.use();
            setWireframe(oldWireframe);
        }
    }

    // D MINECRAFT MAP VIEWER CLONE INSPIRATION ETC
    // https://github.com/Wallbraker/Charged-Miners
    // wiki is down so arbitrary place is best for future reference and documentation.

    void renderDudes(Camera camera, float tickTimeSoFar) {
        //TODO: Remove camera position from dudes!! Matrix to set = proj*viewRotation
        auto vp = camera.getProjectionMatrix() * camera.getViewMatrix();
        dudeShader.use();
        dudeShader.setUniform(dudeShader.VP, vp);
        glEnableVertexAttribArray(0);
        glError();
        auto dudes = world.getVisibleUnits(camera);
        foreach(dude ; dudes) {
            renderDude(dude, tickTimeSoFar);
        }
        glDisableVertexAttribArray(0);
        glError();
    }


    //Copied from scheduler.d
    //Consider making this a mixin functionality, sortof.
    //TODO: Think about this functionality. What is it used for? Where is it used? What do we use it for?
    // Is there any place we can put this code to make it usable from other places too?
    enum Frames = 3;
    long[Frames] frameTimes;
    long lastTime;
    ulong frameAvg;
    int frameId;
    void insertFrameTime(){
        long now = utime();
        long delta = now - lastTime;
        lastTime = now;
        frameTimes[frameId] = delta;
        frameId = (frameId+1)%Frames;
        frameAvg = 0;
        foreach(time ; frameTimes) {
            frameAvg += time;
        }
        frameAvg /= Frames;
    }

    float soFar = 0;
    override void update(World world, Scheduler sched) {
        soFar = 0;
    }


    void render()
    {
        long avgTickTime = scheduler.frameAvg;
        float ratio = 0.0f;
        if(avgTickTime > frameAvg){
            ratio = to!float(frameAvg) / to!float(avgTickTime);
        }

        soFar += ratio;

        //TODO: Decide if to move clearing of buffer to outside of renderer, or is render responsible for
        // _ALL_ rendering?
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glError();

        //TODO: Make function setWireframe(bool yes) that does this.
        //Render world
        setWireframe(renderSettings.renderWireframe);
        renderWorld(camera);
        renderDudes(camera, soFar);
        setWireframe(false);

        insertFrameTime();

  }

    void renderGraphicsRegion(const GraphicsRegion region){
        //TODO: Do the pos-camerapos before converting to float, etc
        auto pos = region.grNum.min().value;
        worldShader.setUniform(worldShader.offset, pos);

        glBindBuffer(GL_ARRAY_BUFFER, region.VBO);
        glError();
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, GRVertex.sizeof, null /* offset in vbo */);
        glError();

        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, GRVertex.sizeof, cast(void*)grTexCoordOffset);
        glError();

        glDrawArrays(GL_QUADS, 0, region.quadCount*4);
        glError();
    }

  void renderWorld(Camera camera)
  {
        worldShader.use();
        glEnableVertexAttribArray(0);
        glError();
        glEnableVertexAttribArray(1);
        glError();
        atlas.use();
        auto transform = camera.getProjectionMatrix() * camera.getViewMatrix();
        worldShader.setUniform(worldShader.VP, transform);
        auto regions = vboMaker.getRegions();
        foreach(region ; regions){
            if(region.VBO && camera.inFrustum(region.grNum.getAABB())){
                renderGraphicsRegion(region);
            }
        }
        //Get list of vbo's
        //Do culling    
        //Render vbo's.
        glDisableVertexAttribArray(0);
        glError();
        glDisableVertexAttribArray(1);
        glError();
        worldShader.use(false);
  }
}


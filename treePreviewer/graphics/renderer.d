
module graphics.renderer;

import std.array;
import std.conv;
import std.exception;
import std.format;
import std.stdio;
import std.string;

import stolen.all;

import graphics.camera;
import graphics.debugging;
import graphics.misc;
import graphics.ogl;
import graphics.raycastgpu;
import graphics.renderconstants;
import scene.scenemanager;
import graphics.shader;
import graphics.texture;
import graphics.tilerenderer;

import modules.module_;
import random.catmullrom;
import scheduler;
import settings;
import statistics;
import unit;
import util.util;



class Renderer {
    //TODO: Leave comment on what these members are use for in this class
    //Scheduler scheduler;
    SceneManager sceneManager;
    TileRenderer tileRenderer;
    TileTextureAtlas atlas;
    Camera camera;

    
    alias ShaderProgram!("VP", "M", "color") DudeShaderProgram;
    alias ShaderProgram!("VP", "V", "color", "radius") LineShaderProgram;
    alias ShaderProgram!("albedo", "minecraft", "raycast", "method") LightMixerShaderProgram;

    DudeShaderProgram dudeShader;
    LineShaderProgram lineShader;
    LightMixerShaderProgram lightMixShader;
    
    vec3d*[Unit] specialUnits;
    
    this(Camera c, TileTextureAtlas _atlas, TileRenderer _tileRenderer, SceneManager _sceneManager)
    {
        mixin(LogTime!("RendererInit"));
        camera = c;        
        tileRenderer = _tileRenderer;
        atlas = _atlas;
        sceneManager = _sceneManager;

    }

    bool initialized = false;

    void init() {

        dudeShader = new DudeShaderProgram("shaders/renderDude.vert", "shaders/renderDude.frag");
        dudeShader.bindAttribLocation(0, "position");
        dudeShader.link();
        dudeShader.VP = dudeShader.getUniformLocation("VP");
        dudeShader.M = dudeShader.getUniformLocation("M");
        dudeShader.color = dudeShader.getUniformLocation("color");
        
        lineShader = new LineShaderProgram("shaders/lineShader.vert", "shaders/lineShader.frag");
        lineShader.bindAttribLocation(0, "position");
        lineShader.VP = lineShader.getUniformLocation("VP");
        lineShader.V = lineShader.getUniformLocation("V");
        lineShader.color = lineShader.getUniformLocation("color");
        lineShader.radius = lineShader.getUniformLocation("radius");

        lightMixShader = new LightMixerShaderProgram("shaders/quadShader.vert", "shaders/lightMixer.frag");
        lightMixShader.bindAttribLocation(0, "vertex");
        lightMixShader.link();
        lightMixShader.albedo = lightMixShader.getUniformLocation("albedoTex");
        lightMixShader.minecraft = lightMixShader.getUniformLocation("minecraftLightTex");
        lightMixShader.raycast = lightMixShader.getUniformLocation("raycastLightTex");
        lightMixShader.method = lightMixShader.getUniformLocation("method");
        lightMixShader.use();
        lightMixShader.setUniform(lightMixShader.albedo, 5);
        lightMixShader.setUniform(lightMixShader.minecraft, 6);
        lightMixShader.setUniform(lightMixShader.raycast, 7);
        lightMixShader.use(false);


        createDudeModel();
        createEntityModel();
        createTorchModel();

        tileRenderer.init();
        atlas.upload();

        initialized = true;
    }
    
    void destroy() {
        tileRenderer.destroy();
        dudeShader.destroy();
        lineShader.destroy();
    }

    //TODO: Eventually implement models, etc
    uint dudeVBO;
    void createDudeModel(){
        vec3f[] vertices;
        //Body centered at 0.5 z so main body centered aroung local origo
        vertices ~= makeCube(vec3f(0.5, 0.5, 1), vec3f(0, 0, 0.0)); //Body, -.5, -.5, -1 -> .5, .5, 1
        vertices ~= makeCube(vec3f(1, 1, 1), vec3f(0, 0, 1)); //Head, -1, -1, 1 -> 1, 1, 2.0
        glGenBuffers(1, &dudeVBO);
        glError();
        glBindBuffer(GL_ARRAY_BUFFER, dudeVBO);
        glError();
        glBufferData(GL_ARRAY_BUFFER, vertices.length*vec3f.sizeof, vertices.ptr, GL_STATIC_DRAW);
        glError();
    }
    uint entityVBO;
    void createEntityModel(){
        vec3f[] vertices;
        //Body centered at 0.5 z so main body centered aroung local origo
        vertices ~= makeCube(vec3f(0.5, 0.5, 1), vec3f(0, 0, 1.0)); //Body, -.5, -.5, -1 -> .5, .5, 1
        vertices ~= makeCube(vec3f(1, 1, 1), vec3f(0, 0, 0)); //Head, -1, -1, 1 -> 1, 1, 2.0
        glGenBuffers(1, &entityVBO);
        glError();
        glBindBuffer(GL_ARRAY_BUFFER, entityVBO);
        glError();
        glBufferData(GL_ARRAY_BUFFER, vertices.length*vec3f.sizeof, vertices.ptr, GL_STATIC_DRAW);
        glError();
    }
    uint torchVBO;
    void createTorchModel(){
        vec3f[] vertices;
        vertices ~= makeCube(vec3f(0.2, 0.2, 0.4), vec3f(0, 0, 0.0));
        vertices ~= makeCube(vec3f(0.2, 0.2, 0.4), vec3f(0, 0, 0.0));
        glGenBuffers(1, &torchVBO);
        glError();
        glBindBuffer(GL_ARRAY_BUFFER, torchVBO);
        glError();
        glBufferData(GL_ARRAY_BUFFER, vertices.length*vec3f.sizeof, vertices.ptr, GL_STATIC_DRAW);
        glError();
    }
    
    void renderAABB(aabbox3d!(double) bb){
        auto v = camera.getViewMatrix();
        auto vp = camera.getProjectionMatrix() * v;
        lineShader.use();
        lineShader.setUniform(lineShader.VP, vp);
        lineShader.setUniform(lineShader.V, v);
        glEnableVertexAttribArray(0);
        glError();

        bool oldWireframe = setWireframe(true);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        vec3d[8] edges;
        bb.getEdges(edges);

        glVertexAttribPointer(0, 3, GL_DOUBLE, GL_FALSE, vec3d.sizeof, edges.ptr);
        glError();
        lineShader.setUniform(lineShader.color, vec3f(0.8, 0.0, 0));
        lineShader.setUniform(lineShader.radius, 100.0f);
        immutable ubyte[] indices = [0, 1, 0, 4, 0, 2, 2, 6, 2, 3, 5, 1, 5, 4, 6, 2, 6, 4, 6, 7, 7, 5, 7, 3];
        glDrawElements(GL_LINES, indices.length, GL_UNSIGNED_BYTE, indices.ptr);
        glError();
        //dudeShader.use();
        setWireframe(oldWireframe);
        
        
        glDisableVertexAttribArray(0);
        glError();        
        lineShader.use(false);
    }
    
    void renderDebug(Camera camera){
        auto v = camera.getViewMatrix();
        auto vp = camera.getProjectionMatrix() * v;
        lineShader.use();
        lineShader.setUniform(lineShader.VP, vp);
        lineShader.setUniform(lineShader.V, v);
        glEnableVertexAttribArray(0);
        glError();
        
        void set(vec3f color, float radius){
            lineShader.setUniform(lineShader.color, color);
            lineShader.setUniform(lineShader.radius, radius);            
        }

        bool oldWireframe = setWireframe(true);
        renderAABBList(&set);
        renderLineList(&set);
        setWireframe(oldWireframe);
        glDisableVertexAttribArray(0);
        glError();
        lineShader.use(false);
    }
    
        

    void renderDude(Unit unit, float tickTimeSoFar){
        auto M = matrix4();
        vec3d unitPos;
        vec3d **p = unit in specialUnits;
        if (p !is null) {
            unitPos = **p;
        } else {
            unitPos = unit.pos.value; //TODO: Subtract the camera position from the unit before rendering
        }
        unitPos += tickTimeSoFar * unit.velocity;
        M.setTranslation(unitPos.convert!float());
        M.setRotationRadians(vec3f(0, 0, unit.rotation));
        dudeShader.setUniform(dudeShader.M, M);
        dudeShader.setUniform(dudeShader.color,
                vec3f(unit.type.tintColor.X/255.0f,
													  unit.type.tintColor.Y/255.0f,
													  unit.type.tintColor.Z/255.0f)); //Color :p
        glBindBuffer(GL_ARRAY_BUFFER, dudeVBO);
        glError();
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, null /* offset in vbo */);
        glError();

        glDrawArrays(GL_QUADS, 0, 4*6*2 /*2 cubes */);
        glError();


        //TODO: Move to own function, make own shader or abstractify a "simpleshader"-thing to use.
        const bool RenderDudeAABB = false;
        static if(RenderDudeAABB == true){
            dudeShader.use(false);
            renderAABB(unit.aabb);
            dudeShader.use();
        }
    }
    
    void normalUnit(Unit unit) {
        specialUnits[unit] = null;
    }
    vec3d* specialUnit(Unit unit, vec3d pos) {
        auto p = new vec3d(pos);
        specialUnits[unit] = p;
        return p;
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
        pragma(msg, "Implment scene graph");
        auto dudes = []; //world.getVisibleUnits(camera);
        /*
        foreach(dude ; dudes) {
            renderDude(dude, tickTimeSoFar);
        }
        */
        glDisableVertexAttribArray(0);
        dudeShader.use(false);
        glError();
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }


    void castShadowRays() {
        if(renderSettings.renderTrueWorld == 1 || 
           renderSettings.renderTrueWorld == 3 || 
           renderSettings.renderTrueWorld == 4) return;
        pragma(msg, "refactor raycasting");
        //interactiveComputeYourFather(world, camera);
    }

    void finishHim() {

        glActiveTexture(GL_TEXTURE5);
        glError();
        glBindTexture(GL_TEXTURE_2D, g_albedoTexture);
        glError();

        glActiveTexture(GL_TEXTURE6);
        glError();
        glBindTexture(GL_TEXTURE_2D, g_lightTexture);
        glError();

        glActiveTexture(GL_TEXTURE7);
        glError();
        glBindTexture(GL_TEXTURE_2D, g_rayCastOutput);
        glError();

        //

        lightMixShader.use();
        lightMixShader.setUniform(lightMixShader.method, renderSettings.renderTrueWorld);
        renderQuad();
        lightMixShader.use(false);

        //Render stuff, make things.
    }
    
    void render(long usecs, double timeOfDay)
    {
        if(!initialized) return;
        
        g_Statistics.addFPS(usecs);

        vec3f skyColor = CatmullRomSpline(timeOfDay, SkyColors);

        //TODO: Make function setWireframe(bool yes) that does this.
        //Render world
        glBindFramebuffer(GL_FRAMEBUFFER, g_FBO); glError();
        glClearColor(skyColor.X, skyColor.Y, skyColor.Z, 0.0f); glError();
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT); glError();

        setWireframe(renderSettings.renderWireframe);



        atlas.use();
        tileRenderer.render(camera, skyColor);

        sceneManager.renderScene(camera);

        //renderDudes(camera, 0.0f);
		//renderEntities(camera, 0.0f);
        renderDebug(camera);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glError();
    
        castShadowRays();
        finishHim();

        setWireframe(false);
  }

	
	void renderEntity(Entity entity, float tickTimeSoFar){
        auto M = matrix4();
        vec3d entityPos;
        /*vec3d **p = entity in specialUnits;
        if (p !is null) {
            entityPos = **p;
        } else {*/
            entityPos = entity.pos.value; //TODO: Subtract the camera position from the unit before rendering
        //}
        M.setTranslation(entityPos.convert!float());
        M.setRotationRadians(vec3f(0, 0, entity.rotation));
		if (entity.isDropped){
			M.setScale(vec3f(0.2f, 0.2f, 0.2f));
		}
        dudeShader.setUniform(dudeShader.M, M);
        dudeShader.setUniform(dudeShader.color,
                vec3f(entity.type.tintColor.X/255.0f,
													  entity.type.tintColor.Y/255.0f,
													  entity.type.tintColor.Z/255.0f)); //Color :p

        // TODO: sry for extreme ugly hack... lazy and stuff
        if (entity.type.name == "torch") {
            glBindBuffer(GL_ARRAY_BUFFER, torchVBO);
        }
        else{
            glBindBuffer(GL_ARRAY_BUFFER, entityVBO);
        }
        glError();
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, null /* offset in vbo */);
        glError();

        glDrawArrays(GL_QUADS, 0, 4*6*2 /*2 cubes */);
        glError();


        //TODO: Move to own function, make own shader or abstractify a "simpleshader"-thing to use.
        const bool RenderDudeAABB = false;
        static if(RenderDudeAABB == true){
            dudeShader.use(false);
            renderAABB(entity.aabb);
            dudeShader.use();
        }
    }
    

    // D MINECRAFT MAP VIEWER CLONE INSPIRATION ETC
    // https://github.com/Wallbraker/Charged-Miners
    // wiki is down so arbitrary place is best for future reference and documentation.

    void renderEntities(Camera camera, float tickTimeSoFar) {
        //TODO: Remove camera position from dudes!! Matrix to set = proj*viewRotation
        auto vp = camera.getProjectionMatrix() * camera.getViewMatrix();
        dudeShader.use();
        dudeShader.setUniform(dudeShader.VP, vp);
        glEnableVertexAttribArray(0);
        glError();
        auto entities = []; //Implement scenegraph world.getVisibleEntities(camera);
        /*
        foreach(entity ; entities) {
            renderEntity(entity, tickTimeSoFar);
        }
        */
        glDisableVertexAttribArray(0);
        dudeShader.use(false);
        glError();
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }

}

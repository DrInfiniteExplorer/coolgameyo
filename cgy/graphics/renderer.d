
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
import graphics.renderconstants;
import scene.scenemanager;
import graphics.shader;
import graphics.texture;
import graphics.tilerenderer;

import heightsheets.heightsheets;
import modules.module_;
import random.catmullrom;
import scheduler;
import settings;
import statistics;
import unit;
import util.util;

alias void delegate (vec3f color, float radius) SetDelegate;
__gshared SetDelegate setDelegate = null;

class Renderer {
    //TODO: Leave comment on what these members are use for in this class
    //Scheduler scheduler;
    SceneManager sceneManager;
    TileRenderer tileRenderer;
    TileTextureAtlas atlas;
    Camera camera;

    HeightSheets heightSheets;
    
    alias ShaderProgram!("VP", "M", "color") DudeShaderProgram;
    alias ShaderProgram!("VP", "V", "color", "radius") LineShaderProgram;
    alias ShaderProgram!("albedo", "minecraft", "raycast", "method") LightMixerShaderProgram;

    DudeShaderProgram dudeShader;
    LineShaderProgram lineShader;
    LightMixerShaderProgram lightMixShader;
    
    vec3d*[Unit] specialUnits;
    
    this(Camera c, TileTextureAtlas _atlas, TileRenderer _tileRenderer, SceneManager _sceneManager, HeightSheets _heightSheets)
    {
        mixin(LogTime!("RendererInit"));
        camera = c;        
        tileRenderer = _tileRenderer;
        atlas = _atlas;
        sceneManager = _sceneManager;
        heightSheets = _heightSheets;

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


        tileRenderer.init();
        heightSheets.init();
        atlas.upload();

        initialized = true;
    }
    
    void destroy() {
        sceneManager.destroy();
        heightSheets.destroy();
        tileRenderer.destroy();
        dudeShader.destroy();
        lineShader.destroy();
        atlas.destroy();
    }


    void renderDebug(Camera camera){
        auto v = camera.getTargetMatrix();
        auto vp = camera.getProjectionMatrix() * v;
        lineShader.use();
        lineShader.setUniform(lineShader.VP, vp);
        lineShader.setUniform(lineShader.V, v);
        glEnableVertexAttribArray(0);
        glError();

        if(setDelegate is null) {
            static auto derp(LineShaderProgram lineShader) {
                void set(vec3f color, float radius){
                    lineShader.setUniform(lineShader.color, color);
                    lineShader.setUniform(lineShader.radius, radius);            
                }
                return &set;
            }
            setDelegate = derp(lineShader);
        }
        
        //Now set is the same always!
        //msg("Set is same always? ", cast(void*)(setDelegate));

        bool oldWireframe = setWireframe(true);
        renderAABBList(camera.getPosition(), setDelegate);
        renderLineList(camera.getPosition(), setDelegate);
        setWireframe(oldWireframe);
        glDisableVertexAttribArray(0);
        glError();
        lineShader.use(false);
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
    
    void render(float deltaT, double timeOfDay)
    {
        if(!initialized) return;
        
        //g_Statistics.addFPS(usecs);

        vec3f skyColor = CatmullRomSpline(timeOfDay, SkyColors);

        //TODO: Make function setWireframe(bool yes) that does this.
        //Render world
        glBindFramebuffer(GL_FRAMEBUFFER, g_FBO); glError();
        glClearColor(skyColor.x, skyColor.y, skyColor.z, 0.0f); glError();
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT); glError();

        setWireframe(renderSettings.renderWireframe);



        atlas.use();
        triCount = 0;

        heightSheets.render(camera);

        tileRenderer.render(camera, skyColor);

        sceneManager.renderScene(camera);

        //renderDudes(camera, 0.0f);
		//renderEntities(camera, 0.0f);
        renderDebug(camera);


        setWireframe(false);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glError();
    
        castShadowRays();
        finishHim();

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


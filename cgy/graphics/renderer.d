
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
import graphics.shader;
import graphics.texture;
import graphics.geometrycreator;

import modules.module_;
import random.catmullrom;
import scheduler;
import settings;
import statistics;
import unit;
import util.util;
import world.world;
import world.floodfill;


//TODO: Make fix this, or make testcase and report it if not done already.
auto grTexCoordOffset = GRVertex.texcoord.offsetof;
auto grNormalOffset = GRVertex.normal.offsetof;
auto grLightOffset = GRVertex.light.offsetof;
auto grSunLightOffset = GRVertex.sunLight.offsetof;

class Renderer {
    //TODO: Leave comment on what these members are use for in this class
    World world;
    Scheduler scheduler;
    GeometryCreator geometryCreator;
    Camera camera;

    TileTextureAtlas atlas;
    
    alias ShaderProgram!("offset", "VP", "atlas", "SkyColor") WorldShaderProgram;
    alias ShaderProgram!("VP", "M", "color") DudeShaderProgram;
    alias ShaderProgram!("VP", "V", "color", "radius") LineShaderProgram;
    alias ShaderProgram!("albedo", "minecraft", "raycast", "method") LightMixerShaderProgram;

    WorldShaderProgram worldShader;
    DudeShaderProgram dudeShader;
    LineShaderProgram lineShader;
    LightMixerShaderProgram lightMixShader;
    
    vec3d*[Unit*] specialUnits;
    
    this(World w, Scheduler s, Camera c, GeometryCreator g)
    {
        mixin(LogTime!("RendererInit"));
        world = w;
        scheduler = s;
        camera = c;        
        geometryCreator = g;

        //Would be kewl if with templates and compile-time one could specify uniform names / attrib slot names
        //that with help of shaders where made into member variables / compile-time-lookup(attrib slot names)
        worldShader = new WorldShaderProgram("shaders/renderGR.vert", "shaders/renderGR.frag");
        worldShader.bindAttribLocation(0, "position");
        worldShader.bindAttribLocation(1, "texcoord");
        worldShader.bindAttribLocation(2, "light");
        worldShader.bindAttribLocation(3, "sunLight");
        worldShader.bindAttribLocation(4, "normal");
        worldShader.link();
        worldShader.offset = worldShader.getUniformLocation("offset");
        worldShader.VP = worldShader.getUniformLocation("VP");
        worldShader.atlas = worldShader.getUniformLocation("atlas");
        worldShader.SkyColor = worldShader.getUniformLocation("SkyColor");
        worldShader.use();
        worldShader.setUniform(worldShader.atlas, 0); //Texture atlas will always reside in texture unit 0 yeaaaah

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
        lightMixShader.setUniform(lightMixShader.albedo, 3);
        lightMixShader.setUniform(lightMixShader.minecraft, 4);
        lightMixShader.setUniform(lightMixShader.raycast, 5);
        lightMixShader.use(false);





        createDudeModel();
        createEntityModel();
        createTorchModel();
    }
    
    void destroy() {
        geometryCreator.destroy();
        worldShader.destroy();
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
        vertices ~= makeCube(vec3f(0.2, 0.2, 0.6), vec3f(0, 0, 0.0));
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
        lineShader.setUniform(lineShader.radius, 100.f);
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
    
        

    void renderDude(Unit* unit, float tickTimeSoFar){
        auto M = matrix4();
        vec3d unitPos;
        vec3d **p = unit in specialUnits;
        if (p !is null) {
            unitPos = **p;
        } else {
            unitPos = unit.pos.value; //TODO: Subtract the camera position from the unit before rendering
        }
        unitPos += tickTimeSoFar * unit.velocity;
        M.setTranslation(util.util.convert!float(unitPos));
        M.setRotationRadians(vec3f(0, 0, unit.rotation));
        dudeShader.setUniform(dudeShader.M, M);
        dudeShader.setUniform(dudeShader.color, vec3f(unit.type.tintColor.X/255.f,
													  unit.type.tintColor.Y/255.f,
													  unit.type.tintColor.Z/255.f)); //Color :p
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
    
    void normalUnit(Unit *unit) {
        specialUnits[unit] = null;
    }
    vec3d* specialUnit(Unit *unit, vec3d pos) {
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
        auto dudes = world.getVisibleUnits(camera);
        foreach(dude ; dudes) {
            renderDude(dude, tickTimeSoFar);
        }
        glDisableVertexAttribArray(0);
        dudeShader.use(false);
        glError();
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }


    void castShadowRays() {
        if(renderSettings.renderTrueWorld == 1 || 
           renderSettings.renderTrueWorld == 3 || 
           renderSettings.renderTrueWorld == 4) return;
        interactiveComputeYourFather(world, camera);
    }

    void finishHim() {

        glActiveTexture(GL_TEXTURE3);
        glError();
        glBindTexture(GL_TEXTURE_2D, g_albedoTexture);
        glError();

        glActiveTexture(GL_TEXTURE4);
        glError();
        glBindTexture(GL_TEXTURE_2D, g_lightTexture);
        glError();

        glActiveTexture(GL_TEXTURE5);
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
    
    void render(long usecs)
    {
        
        g_Statistics.addFPS(usecs);

        //TODO: Decide if to move clearing of buffer to outside of renderer, or is render responsible for
        // _ALL_ rendering?

        //TODO: Make function setWireframe(bool yes) that does this.
        //Render world
        glBindFramebuffer(GL_FRAMEBUFFER, g_FBO);
        glError();
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glError();

        setWireframe(renderSettings.renderWireframe);
        renderWorld(camera);
        renderDudes(camera, 0.f);
		renderEntities(camera, 0.f);
        renderDebug(camera);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glError();
    
        castShadowRays();

        finishHim();

        setWireframe(false);
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

        glVertexAttribPointer(2, 1, GL_FLOAT, GL_FALSE, GRVertex.sizeof, cast(void*)grLightOffset);
        glError();

        glVertexAttribPointer(3, 1, GL_FLOAT, GL_FALSE, GRVertex.sizeof, cast(void*)grSunLightOffset);
        glError();

        glVertexAttribPointer(4, 1, GL_FLOAT, GL_FALSE, GRVertex.sizeof, cast(void*)grNormalOffset);
        glError();

        glDrawArrays(GL_QUADS, 0, region.quadCount*4);
        glError();
    }

    immutable vec3f NightBlue = vec3f(0.0, 0.0, 0.2);
    immutable vec3f SunLighty = vec3f(1.0, 1.0, 1.0);
    immutable vec3f SunSet    = vec3f(0.9, 0.9, 0.7);
    immutable vec3f SunSetter = vec3f(0.4, 0.4, 0.5);
    immutable vec3f[] SkyColorDerp = [
        NightBlue,
        NightBlue,
        SunSet,
        SunLighty,
        SunLighty,
        SunLighty,
        SunSet,
        SunSetter,
        NightBlue,
    ];

    void renderWorld(Camera camera)
    {
        worldShader.use();
        glEnableVertexAttribArray(0);
        glError();
        glEnableVertexAttribArray(1);
        glError();
        glEnableVertexAttribArray(2);
        glError();
        glEnableVertexAttribArray(3);
        glError();
        glEnableVertexAttribArray(4);
        glError();
        atlas.use();
        auto transform = camera.getProjectionMatrix() * camera.getViewMatrix();
        worldShader.setUniform(worldShader.VP, transform);
        vec3f SkyColor = CatmullRomSpline(world.getDayTime(), SkyColorDerp);
        worldShader.setUniform(worldShader.SkyColor, SkyColor);
        auto regions = geometryCreator.getRegions();
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
        glDisableVertexAttribArray(2);
        glError();
        glDisableVertexAttribArray(3);
        glError();
        glDisableVertexAttribArray(4);
        glError();
        worldShader.use(false);
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
        M.setTranslation(util.util.convert!float(entityPos));
        M.setRotationRadians(vec3f(0, 0, entity.rotation));
		if (entity.isDropped){
			M.setScale(vec3f(0.2f, 0.2f, 0.2f));
		}
        dudeShader.setUniform(dudeShader.M, M);
        dudeShader.setUniform(dudeShader.color, vec3f(entity.type.tintColor.X/255.f,
													  entity.type.tintColor.Y/255.f,
													  entity.type.tintColor.Z/255.f)); //Color :p

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
        auto entities = world.getVisibleEntities(camera);
        foreach(entity ; entities) {
            renderEntity(entity, tickTimeSoFar);
        }
        glDisableVertexAttribArray(0);
        dudeShader.use(false);
        glError();
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }

}



module graphics.renderer;

import std.algorithm : min, max;
import std.array;
import std.conv;
import std.exception;
import std.format;
import std.math : abs;
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
static import scheduler;
import settings;
import statistics;
import unit;
import util.util;

alias void delegate (vec3f color, float radius) SetDelegate;
__gshared SetDelegate setDelegate = null;

immutable lineShaderVert = q{
    #version 420
    uniform mat4 V;
    uniform mat4 VP;
    uniform vec3 offset;
    in vec3 position;
    out vec3 viewPos;   
    smooth out vec3 worldPosition;
    void main(){
        vec4 p = vec4(position + offset, 1.0);
        viewPos = (V * p).xyz;
        gl_Position = VP * p;
        worldPosition = p.xyz;
    }
};

immutable lineShaderFrag = q{
    #version 420

    uniform vec3 color;
    uniform float radius;
    in vec3 viewPos;
    smooth in vec3 worldPosition;
    layout(location = 0) out vec4 frag_color;
    layout(location = 1) out vec4 light;
    layout(location = 2) out vec4 depth;
    void main() {
        //float dist = length(viewPos);
        //float tmp = 1.0 - dist/radius;
        frag_color = vec4(color, 1.0);
        depth = vec4(worldPosition, float(1.0));
        light = vec4(1.0);
    } 
};

class Renderer {

    //TODO: Leave comment on what these members are use for in this class
    SceneManager sceneManager;
    TileRenderer tileRenderer;
    TileTextureAtlas atlas;
    Camera camera;

    HeightSheets heightSheets;
    
    alias ShaderProgram!("VP", "V", "offset", "color", "radius") LineShaderProgram;
    alias ShaderProgram!("method") LightMixerShaderProgram;

    LineShaderProgram lineShader;
    LightMixerShaderProgram lightMixShader;

    //int minZ = int.max;
    int minZ = 420;

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
        
        lineShader = new LineShaderProgram(makeStackArray(lineShaderVert, lineShaderFrag));
        lineShader.bindAttribLocation(0, "position");
        lineShader.link();
        lineShader.VP = lineShader.getUniformLocation("VP");
        lineShader.V = lineShader.getUniformLocation("V");
        lineShader.color = lineShader.getUniformLocation("color");
        lineShader.radius = lineShader.getUniformLocation("radius");
        lineShader.use();
        lineShader.use(false);

        lightMixShader = new LightMixerShaderProgram("shaders/quadShader.vert", "shaders/lightMixer.frag");
        lightMixShader.bindAttribLocation(0, "vertex");
        lightMixShader.link();
        lightMixShader.method = lightMixShader.getUniformLocation("method");
        lightMixShader.use();
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
        lineShader.destroy();
        atlas.destroy();
    }


    void renderDebug(Camera camera){
        auto v = camera.getTargetMatrix();
        auto vp = camera.getProjectionMatrix() * v;
        lineShader.use();
        lineShader.setUniform(lineShader.VP, vp);
        lineShader.setUniform(lineShader.V, v);
        lineShader.uniform.offset = vec3f(0);
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

    void castShadowRays() {
        if(renderSettings.renderTrueWorld == 1 || 
           renderSettings.renderTrueWorld == 3 || 
           renderSettings.renderTrueWorld == 4) return;
        pragma(msg, "refactor raycasting");
        //interactiveComputeYourFather(world, camera);
    }

    void finishHim() {

        glActiveTexture(GL_TEXTURE5); glError();
        glBindTexture(GL_TEXTURE_2D, g_albedoTexture); glError();

        glActiveTexture(GL_TEXTURE6); glError();
        glBindTexture(GL_TEXTURE_2D, g_lightTexture); glError();

        glActiveTexture(GL_TEXTURE7); glError();
        glBindTexture(GL_TEXTURE_2D, g_rayCastOutput); glError();

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

        //Render world
        glBindFramebuffer(GL_FRAMEBUFFER, g_FBO); glError();
        glClearColor(skyColor.x, skyColor.y, skyColor.z, 1.0f); glError();
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT); glError();

        setWireframe(renderSettings.renderWireframe);

        atlas.use();
        triCount = 0;

        heightSheets.render(camera);
        tileRenderer.render(camera, skyColor, minZ);
        sceneManager.renderScene(camera);

        renderGrid();
        renderDesignations();

        renderDebug(camera);

        setWireframe(false);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glError();
    
        castShadowRays();
        finishHim();

    }

    long lastMineDesignation;
    vec3d designationUpdatedAt;
    vec3f[24][] mineDesignations;
    void renderDesignations() {
        auto playerUnit = game.getActiveUnit();
        if(playerUnit is null) return;
        auto clan = playerUnit.clan;
        auto cameraPos = camera.position;
        if(lastMineDesignation != clan.toMineUpdated) {
            lastMineDesignation = clan.toMineUpdated;
            auto toMine = clan.getMineDesignations();
            vec3d[24] mineDesignationsD;
            mineDesignations.length = toMine.length;
            foreach(idx, tilePos ; toMine) {
                auto aabb = tilePos.getAABB();
                aabb.scale(1.05);
                mineDesignationsD = aabb.getQuads();
                foreach(ref vec ; mineDesignationsD) {
                    vec -= cameraPos;
                }
                mineDesignations[idx].convertArray(mineDesignationsD);
            }
            designationUpdatedAt = cameraPos;
        }
        if(mineDesignations.length == 0) return;
        auto v = camera.getTargetMatrix();
        auto vp = camera.getProjectionMatrix() * v;

        lineShader.use();
        lineShader.uniform.VP =  vp;
        lineShader.uniform.V = v;

        lineShader.uniform.color = vec3f(0.9, 0.65, 0.2);
        lineShader.uniform.ignore.radius = 10.0f;

        lineShader.uniform.offset = (designationUpdatedAt - cameraPos).convert!float;

        glEnableVertexAttribArray(0); glError();
        glBindBuffer(GL_ARRAY_BUFFER, 0); glError();
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, cast(const void*)mineDesignations.ptr); glError();

        auto a = vp.transformVect((cast(vec3f*)mineDesignations.ptr)[0]);

        glDrawArrays(GL_QUADS, 0, cast(int)mineDesignations.length * 24);
        glDrawArrays(GL_LINES, 0, cast(int)mineDesignations.length * 24);

        glDisableVertexAttribArray(0); glError();
        lineShader.use(false);


    }


    vec3f[4] selectionQuad;
    vec2i selectionQuadStart;
    vec2f selectionQuadSize;
    vec3f selectionColor;
    void setSelection(vec2i corner1, vec2i corner2, vec3f* color = null) {
        if(color !is null) {
            selectionColor = *color;
        }
        selectionQuadStart.x = min(corner1.x, corner2.x);
        selectionQuadStart.y = min(corner1.y, corner2.y);
        selectionQuadSize.x = abs(corner1.x - corner2.x);
        selectionQuadSize.y = abs(corner1.y - corner2.y);
    }

    vec3f[2][] gridLines;
    void renderGrid() {
        if(minZ == int.max) {
            return;
        }
        if(gridLines.length == 0) {
            int gridSize = 25;
            float x1 = -gridSize;
            float x2 = gridSize;
            float y1 = -gridSize;
            float y2 = gridSize;
            foreach(y ; -gridSize .. gridSize) {
                gridLines ~= makeStackArray( vec3f(x1, y, 0), vec3f(x2, y, 0));
            }
            foreach(x ; -gridSize .. gridSize) {
                gridLines ~= makeStackArray( vec3f(x, y1, 0), vec3f(x, y2, 0));
            }
        }
        // Render grid. Wooh.
        auto v = camera.getTargetMatrix();
        auto vp = camera.getProjectionMatrix() * v;
        vec3f offset = vec3f(-camera.position.x % 1.0, -camera.position.y % 1.0, minZ - camera.position.z);
        lineShader.use();
        lineShader.uniform.VP =  vp;
        lineShader.uniform.V = v;
        lineShader.uniform.offset = offset;

        glEnableVertexAttribArray(0); glError();

        lineShader.uniform.color = vec3f(0.1, 0.1, 0.7);
        lineShader.uniform.ignore.radius = 10.0f;
        glBindBuffer(GL_ARRAY_BUFFER, 0); glError();

        glLineWidth(2.5);
        //bool oldWireframe = setWireframe(true);
        //scope(exit) setWireframe(oldWireframe);

        /*
        if(gridPointSelectionMarker !is null) {
            auto relPt = (gridPointSelectionMarker - camera.position).convert!float;
            pts ~= makeStackArray(relPt, relPt + vec3f(0,0,1));
        }
        */

        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, cast(const void*)gridLines.ptr); glError();
        glDrawArrays(GL_LINES, 0, cast(int)gridLines.length * 2);

        selectionQuad[] = (selectionQuadStart.v3(minZ).convert!double - camera.position).convert!float;
        selectionQuad[1].x += selectionQuadSize.x;
        selectionQuad[2] += selectionQuadSize.v3(0);
        selectionQuad[3].y += selectionQuadSize.y;

        lineShader.uniform.color = selectionColor;
        lineShader.uniform.offset = vec3f(0, 0, 0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, cast(const void*)selectionQuad.ptr); glError();
        glDrawArrays(GL_QUADS, 0, cast(int)selectionQuad.length);

        glDisableVertexAttribArray(0); glError();
        lineShader.use(false);
    }

}


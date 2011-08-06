
module game;

import core.thread;

import std.algorithm;
import std.array;
import std.concurrency;
import std.conv;
import std.exception;
import std.stdio;

import derelict.sdl.sdl;

import graphics.ogl;
import graphics.camera;
import graphics.font;
import graphics.renderer;
import graphics.texture;

import graphics.debugging;

import ai.patrolai;
import changelist;
import modules.ai;
import modules.path;
import pos;
import scheduler;
import tiletypemanager;
import util;
import unit;
import world;
import worldgen.worldgen;

import settings;

string SDLError() { return to!string(SDL_GetError()); }

class Game{

    private World           world;


    private bool            isClient;
    private bool            isServer;
    private bool            isWorker;

    private Camera              camera;
    private Renderer            renderer;
    private Scheduler           scheduler;
    private TileTextureAtlas    atlas;
    private TileTypeManager     tileTypeManager;    
    private PathModule          pathModule;
    private AIModule            aiModule;
    
    private Unit*               activeUnit; //TODO: Find out when this unit dies, and tell people.
    
    

    this(bool serv, bool clie, bool work) {
        //TODO: Move world-creation etc out of here, and put in init-function instead.
        //We might want to load stuff, so worldgen-settings for example should be 
        //passed elsewhere.
        isServer = serv;
        isClient = clie;
        isWorker = work;
    }
    
    private bool destroyed;
    ~this() {
        enforce(destroyed, "Game.destroyed not called!");
    }
    
    private void init(WorldGenParams worldParams) {
        if (isClient) {
            atlas = new TileTextureAtlas; // HACK
            //TODO: Find out what the above comment indicates.
        }
        tileTypeManager = new TileTypeManager(atlas);
        world = new World(worldParams, tileTypeManager);
        assert (isWorker, "otherwise wont work lol (maybe)");

        scheduler = new Scheduler(world);
        pathModule = new PathModule;
        aiModule = new AIModule(pathModule, world);
        scheduler.registerModule(pathModule);
        scheduler.registerModule(aiModule);
        
        if (isClient) {
            camera = new Camera();
            renderer = new Renderer(world, scheduler, camera);
            renderer.atlas = atlas;
            
            atlas.upload();
            camera.setPosition(vec3d(-2, -2, 20));
            camera.setTarget(vec3d(0, 0, 20));
        }
        
    }
    
    void populateWorld() {
        UnitPos topOfTheWorld(TileXYPos xy) {
            auto top = world.getTopTilePos(xy);
            msg("top: ", top);
            auto ret = top.toUnitPos();
            ret.value.Z += 1;
            msg("ret: ", ret);
			
            return ret;
        }

        auto xy = TileXYPos(vec2i(3,-20));
        auto u = new Unit;
        u.pos = topOfTheWorld(xy);
        //u.pos.value.Z += 1;
        world.addUnit(u);
        
        msg("u.pos == ", u.pos);

        auto uu = new Unit;
        auto xyy = TileXYPos(vec2i(3,3));
        uu.pos = topOfTheWorld(xyy);
        world.addUnit(uu);      
        //auto goal = UnitPos(u.pos.value + vec3d(-30, 0, 0));
        auto goal = uu.pos;
        //NO AI FOR NO PATHABLENESS WITH NEW RANDOMMAPNESS
        u.ai = new PatrolAI(u, goal, pathModule);
        goal.value.Z += 1;
        addAABB(goal.tilePos.getAABB());
        //u.ai = new DwarfAI(u);
        
        activeUnit = uu;
        
    }

    void newGame(WorldGenParams worldParams) {
        init(worldParams);
        populateWorld();
        camera.setPosition(vec3d(0, 0, 0));
        camera.setTarget(vec3d(0, 1, 0));
        world.floodFillSome(1_000_000);

        scheduler.start();
    }
    
    void loadGame(string name) {
        enforce(0, "Implement!");
        //init(worldParams);
        //Deserialize into world and stufffff!
        //Load camera! Active unit! Stuff!
        scheduler.start();
    }
    
    void saveGame(string name) {
        enforce(0, "Implement!");
    }
    
    void destroy() {
        //Wait until done.
        scheduler.exit();
        while(scheduler.running()){
            msg("Waiting for scheduler to terminate worker threads...");
            Thread.sleep(dur!"seconds"(1));
        }

        atlas.destroy();
        renderer.destroy();
        world.destroy();

        destroyed = true;
    }
    
    Camera getCamera() {
        return camera;
    }
    
    Unit* getActiveUnit() {
        return activeUnit;
    }
    
    World getWorld() {
        return world;
    }
    
    Renderer getRenderer() {
        return renderer;
    }
    
    Scheduler getScheduler() {
        return scheduler;
    }

    void render() {
        renderer.render();
    }
}








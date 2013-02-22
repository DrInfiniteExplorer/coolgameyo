
module game;

import core.thread;

import std.algorithm;
import std.array;
import std.concurrency;
import std.conv;
import std.exception;
import std.math;
import std.socket;
import std.stdio;
import std.string;

version(Windows) import std.c.windows.windows;

import derelict.sdl.sdl;

import ai.patrolai;
import ai.test;

import clan;
import clans;

import entitytypemanager;

import graphics.camera;
import graphics.debugging;
import graphics.font;
import graphics.ogl;
import graphics.renderer;
import graphics.texture;
import graphics.tilegeometry;
import graphics.tilerenderer;

import heightsheets.heightsheets;
import json;

//import changes.changelist;
import main;
import modules.ai;
import modules.network;
import modules.path;
import util.pos;
import scheduler;
import scene.scenemanager;
import settings;
import statistics;

import tiletypemanager;
import treemanager;

import unittypemanager;
import unit;
import util.util;
import util.filesystem;
import worldstate.worldstate;
//import worldgen.worldgen;
import worldgen.maps;

__gshared bool g_isServer;
__gshared string g_worldPath;

__gshared string g_playerName = ""; //Default player name. What should that be?

string SDLError() { return to!string(SDL_GetError()); }

final class PlayerInformation {
    string name;
    vec2d position;
    //WHAT ELSE?? D:
    //Information about which client he is?
}

class Game{

    WorldMap            worldMap;
    private WorldState          worldState;

    private bool            isClient;
    private bool            isServer;

    private AIModule            aiModule;
    private Camera              camera;
    private EntityTypeManager   entityTypeManager;
    private PathModule          pathModule;
    private Renderer            renderer;
    private SceneManager        sceneManager;
    private Scheduler           scheduler;
    private TileGeometry        tileGeometry;
    private TreeManager         treeManager;
    private TileTextureAtlas    atlas;
    private TileTypeManager     tileTypeManager;
    private UnitTypeManager     unitTypeManager;
    private Unit                activeUnit; //TODO: Find out when this unit dies, and tell people.

    private vec2i               spawnPoint;
    private PlayerInformation[string] players;

    this(bool server) {
        isServer = server;
    }

    private bool destroyed;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {
        //Wait until done.
        if(scheduler) {
            scheduler.exit();
            while(scheduler.running()){
                msg("Waiting for scheduler to terminate worker threads...");
                core.thread.Thread.sleep(dur!"seconds"(1));
            }
        }

        //Also make policy on where stuff is destroyed.
        pragma(msg, "Make so that stuff that is only client, only destroys when is client");
        if(tileGeometry) {
            tileGeometry.destroy();
        }
        if(renderer) {
            renderer.destroy();
        }
        if(worldState) {
            worldState.destroy();
        }
        if(worldMap) {
            worldMap.destroy();
        }

        if(aiModule) {
           aiModule.destroy();
        }

        destroyed = true;
    }


    //This and finishInit are run in the thread which becomes the scheduler thread
    private void init() {

        mixin(LogTime!("GameInit"));
        if (!isServer) {
            atlas = new TileTextureAtlas; // HACK
            //TODO: Find out what the above comment indicates.
        }
        tileTypeManager = new TileTypeManager(atlas);
        entityTypeManager = EntityTypeManager();
        entityTypeManager.init();
        unitTypeManager = UnitTypeManager();
        unitTypeManager.init();
        
        if(!isServer) {
            sceneManager = new SceneManager();
        }

        worldMap = new WorldMap();
        worldMap.loadWorld(g_worldPath);
        worldMap.tileSys = tileTypeManager;
        worldState = new WorldState(worldMap, tileTypeManager, entityTypeManager, unitTypeManager, sceneManager);

        scheduler = new Scheduler(this);
        pathModule = new PathModule;
        aiModule = new AIModule(pathModule, worldState);
        scheduler.registerModule(pathModule);
        scheduler.registerModule(aiModule);
        scheduler.registerModule(Clans());

        if (!isServer) {
            camera = new Camera();
            //The renderer also needs to be created in the main thread, it loads shaders and stuff.
            //Mainly all in this block of code actually :)
            /*
            camera.setPosition(vec3d(-2, -2, 20));
            camera.setTarget(vec3d(0, 0, 20));
            */
            //geometryCreator = new GeometryCreator(world);
            auto tileRenderer = new TileRenderer();
            tileGeometry = new TileGeometry(worldState, tileRenderer);
            auto heightSheets = new HeightSheets(worldMap, worldState);
            renderer = new Renderer(camera, atlas, tileRenderer, sceneManager, heightSheets);
            scheduler.registerModule(tileGeometry);
            scheduler.registerModule(heightSheets);
            tileGeometry.setCamera(camera);
        }
        if(isServer) {
            initServerModule();
        }

    }
    //This and init are run in the thread which becomes the scheduler thread
    private void finishInit() {
        if (!isServer) {
            renderer.init();
        }
        scheduler.start();
    }


    private void populateWorld() {

        g_UnitCount = 0;

        loadJSON(g_worldPath ~ "/start.json").readJSONObject("startPos", &spawnPoint);

        UnitPos topOfTheWorld(TileXYPos xy) {
            auto top = worldState.getTopTilePos(xy);
            auto ret = top.toUnitPos();
            return ret;
        }

        auto clan = newClan(worldState);

        // halfWorldSize_xy
        Unit addUnitAtPos()(vec2i pos) {
            auto xy = TileXYPos(pos);
            auto u = newUnit();
            u.pos = topOfTheWorld(xy);
            u.type = worldState.unitTypeManager.byName("dwarf");
            clan.addUnit(u);
            return u;
        }

        auto uu = addUnitAtPos(vec2i(3,3) + spawnPoint);
        activeUnit = uu;
        worldState._worldProxy.createUnit(uu);

        auto u = addUnitAtPos(vec2i(3,-20) + spawnPoint);
        u.ai = new TestAI(u);
        worldState._worldProxy.createUnit(u);
    } 

    void loadGame() {
        init();
        scheduler.deserialize();
        finishInit();        
    }

    void connect(string host) {
        initClientModule(host);
        init();
        scheduler.deserialize();
        finishInit();
    }

    //Herp derp will be called from scheduler.deserialize. Yeah.
    void deserialize() {

        if(exists(g_worldPath ~ "/start.json")) {
            populateWorld();
            deleteFile(g_worldPath ~ "/start.json");
            return;
        }
        worldState.deserialize();

        auto content = readText(g_worldPath ~ "/game.json");
        auto rootVal = json.parse(content);
        uint activeUnitId;
        uint unitCount;
        if("activeUnit" in rootVal){
            activeUnitId = to!int(rootVal["activeUnit"].num);
        }
        if("unitCount" in rootVal){
            unitCount = to!int(rootVal["unitCount"].num);
        }

        g_UnitCount = unitCount;
        activeUnit = worldState.getUnitFromId(activeUnitId);

    }

    void serialize() {
        //private Unit               activeUnit; //TODO: Find out when this unit dies, and tell people.
        auto activeUnit = Value(activeUnit.id);
        auto unitCount = Value(g_UnitCount);
        auto jsonRoot = Value([
                "activeUnit" : activeUnit,
                "unitCount" : unitCount,
                ]);
        auto jsonString = json.prettifyJSON(jsonRoot);

        std.file.write(g_worldPath ~ "/game.json", jsonString);
        worldState.serialize();
    }

    Camera getCamera() {
        return camera;
    }

    Unit getActiveUnit() {
        return activeUnit;
    }

    WorldState getWorld() {
        return worldState;
    }

    Renderer getRenderer() {
        return renderer;
    }

    Scheduler getScheduler() {
        return scheduler;
    }

    bool getIsServer() {
        return this.isServer;
    }

    void render(long usecs) {
        if(renderer is null) return;
        renderer.render(usecs, worldState.getDayTime());
    }

    mixin ServerModule;
    mixin ClientModule;

}



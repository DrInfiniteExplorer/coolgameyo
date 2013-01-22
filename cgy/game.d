﻿
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
import clientnetworking;

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
import modules.ai;
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






string SDLError() { return to!string(SDL_GetError()); }

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



    this(bool server) {
        isServer = server;

    }

    private bool destroyed;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {
        //Wait until done. 
        scheduler.exit();
        while(scheduler.running()){
            msg("Waiting for scheduler to terminate worker threads...");
            core.thread.Thread.sleep(dur!"seconds"(1));
        }

        //Also make policy on where stuff is destroyed.
        pragma(msg, "Make so that stuff that is only client, only destroys when is client");
        tileGeometry.destroy();
        renderer.destroy();
        worldState.destroy();
        worldMap.destroy();

        aiModule.destroy();

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
        worldMap.loadWorld("saves/current");
        worldMap.tileSys = tileTypeManager;
        worldState = new WorldState(worldMap, tileTypeManager, entityTypeManager, unitTypeManager, sceneManager);

        scheduler = new Scheduler(worldState);
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

        vec2i startPos;
        loadJSON("saves/current/start.json").readJSONObject("startPos", &startPos);

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

        auto uu = addUnitAtPos(vec2i(3,3) + startPos);
        activeUnit = uu;
        worldState._worldProxy.createUnit(uu);

        auto u = addUnitAtPos(vec2i(3,-20) + startPos);
        u.ai = new TestAI(u);
        worldState._worldProxy.createUnit(u);


        /*
        // following is retarded code, ETC :d
        EntityPos topOfTheWorld2(TileXYPos xy) {
            auto top = worldState.getTopTilePos(xy);
            msg("top: ", top);
            auto ret = top.toEntityPos();
            ret.value.Z += 1;
            msg("ret: ", ret);

            return ret;
        }
        auto xy = TileXYPos(vec2i(1,5));
        xy.value += offset;
        auto o = newEntity();
        o.pos = topOfTheWorld2(xy);
        o.type = worldState.entityTypeManager.byName("tree");
        worldState.addEntity(o);
        msg("o.pos == ", o.pos);
        xy = TileXYPos(vec2i(5,1));
        xy.value += offset;
        o = newEntity();
        o.pos = topOfTheWorld2(xy);
        o.type = worldState.entityTypeManager.byName("shrubbery");
        worldState.addEntity(o);
        msg("o.pos == ", o.pos);
        */
    } 

    /*
    void newGame() {

        init();

        populateWorld(startPos);
        /++
        camera.setPosition(vec3d(0, 0, 0));
        camera.setTarget(vec3d(0, 1, 0));
        ++/
        {
            mixin(LogTime!("InitialHeightmaps"));
            worldState.generateAllHeightmaps();
        }
        {
            mixin(LogTime!("InitialFloodFill"));            
            worldState.initialFloodFill();
        }
        finishInit();
    }
    */

    void loadGame() {
        init();
        deserialize();
        finishInit();        
    }

    //Called in loading thread.
    private void deserialize() {

        if(exists("saves/current/start.json")) {
            populateWorld();
            deleteFile("saves/current/start.json");
            return;
        }
        worldState.deserialize();

        auto content = readText("saves/current/game.json");
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

    void serializeAll(void delegate() andThen) {
        void serialize() {
            //private WorldState           world; Tas hand om av scheduler.
            //private bool            isClient;
            //private bool            isServer;
            //private bool            isWorker;

            //Spara position för kameran?
            //private Camera              camera;

            //Behöver inte sparas. Eller? Kan göra det, för snabb laddning av atlas, och flera 'moddar' igång samtidigt.
            //private TileTextureAtlas    atlas;
            //private TileTypeManager     tileTypeManager;    

            //private Unit               activeUnit; //TODO: Find out when this unit dies, and tell people.
            auto activeUnit = Value(activeUnit.id);
            auto unitCount = Value(g_UnitCount);
            auto jsonRoot = Value([
                    "activeUnit" : activeUnit,
                    "unitCount" : unitCount,
                    ]);
            auto jsonString = json.prettifyJSON(jsonRoot);

            std.file.write("saves/current/game.json", jsonString);
        }
        //Takes care of world and tasks.        
        util.filesystem.mkdir("saves/current");
        scheduler.startSerialize({
                writeln("WOHOO!");
                serialize();
                if (andThen !is null) {
                andThen();
                }
                });
    }

    /*
    void saveGame(string name, void delegate() onDone)
        in{
            enforce( name != "current", "Invalid save name: " ~ name);
        }
    body{
        serializeAll({
                string saveDir = "saves/" ~ name;
                if (exists(saveDir)) {
                    rmdir(saveDir);
                }
                //Need to implement a recursive copy function, in util, perhaps?
                util.filesystem.copy("saves/current", saveDir);
                onDone();
                });
    }
    */

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

    void render(long usecs) {
        if(renderer is null) return;
        renderer.render(usecs, worldState.getDayTime());
    }

    mixin NetworkCode; // from clientnetworking.d
}



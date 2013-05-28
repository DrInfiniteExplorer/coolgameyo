
module game;


import std.algorithm;
import std.array;
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
import modules.path;
import network.all;
import util.pos;
import scheduler : scheduler;
import scene.scenemanager;
import settings;
import statistics;

import tiletypemanager;
import treemanager;

import playerinformation;
import unittypemanager;
import unit;
import util.util;
import util.filesystem;
import worldstate.worldstate;
import changes.worldproxy;
import changes.changelist;
//import worldgen.worldgen;
import worldgen.maps;

class Game {

    WorldMap worldMap;
    private WorldState worldState;

    ubyte[] receiveBuffer;
    int send_index;

    private bool isClient;
    private bool isServer;

    private AIModule aiModule;
    private Camera camera;
    private EntityTypeManager entityTypeManager;
    private PathModule pathModule;
    private Renderer renderer;
    private SceneManager sceneManager;
    private TileGeometry tileGeometry;
    private TreeManager treeManager;
    private TileTextureAtlas atlas;
    private TileTypeManager tileTypeManager;
    private UnitTypeManager unitTypeManager;


    private vec2i spawnPoint;

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

        scheduler.init(this);
        scheduler.registerModule(Clans());

        if(isServer) {
            pathModule = new PathModule;
            aiModule = new AIModule(pathModule, worldState);
            scheduler.registerModule(pathModule);
            scheduler.registerModule(aiModule);
        }

        tileTypeManager.generateMaterials();

        if (!isServer) {
            camera = new Camera();

            auto tileRenderer = new TileRenderer();
            tileGeometry = new TileGeometry(worldState, tileRenderer);
            auto heightSheets = new HeightSheets(worldMap, worldState);
            renderer = new Renderer(camera, atlas, tileRenderer, sceneManager, heightSheets);
            renderer.init();
            scheduler.registerModule(tileGeometry);
            scheduler.registerModule(heightSheets);
            tileGeometry.setCamera(camera);
        }
        if(isServer) {
            server.initModule();
        }

    }

    private void populateWorld() {
        loadJSON(g_worldPath ~ "/start.json").readJSONObject("startPos", &spawnPoint);

        UnitPos topOfTheWorld(TileXYPos xy) {
            auto top = worldState.getTopTilePos(xy);
            auto ret = top.toUnitPos();
            return ret;
        }

        auto clan = newClan(worldState);

        // HalfWorldSize_xy
        Unit addUnitAtPos()(vec2i pos) {
            auto xy = TileXYPos(pos);
            auto u = newUnit();
            u.pos = topOfTheWorld(xy);
            u.type = worldState.unitTypeManager.byName("dwarf");
            clan.addUnit(u);
            return u;
        }

        auto uu = addUnitAtPos(spawnPoint);
        activeUnit = uu;
        worldState._worldProxy.createUnit(uu);

    } 

    void loadGame() {
        init();
        scheduler.deserialize();
        scheduler.start(g_maxThreadCount);
        Log("Server running!");
    }

    void connect(string host) {
        client.initModule(host);
        init();
        scheduler.deserialize();
        scheduler.start(g_maxThreadCount);
    }

    //Herp derp will be called from scheduler.deserialize. Yeah.
    void deserialize() {
        if(exists(g_worldPath ~ "/start.json")) {
            populateWorld();
            deleteFile(g_worldPath ~ "/start.json");
            return;
        }
        worldState.deserialize();

        if(exists(g_worldPath ~ "/game.json")) {
            loadJSON(g_worldPath ~ "/game.json").readJSONObject(
                "unitCount", &g_UnitCount,
                "spawnPoint", &spawnPoint);
        }
        if(!isServer) {
            auto top = worldState.getTopTilePos(TileXYPos(spawnPoint));
            auto spawn = top.value.convert!double;
            camera.setPosition(spawn + vec3d(0, 0, 20));
            camera.setTargetDir(vec3d(1.0, 0.0,-1.0));
        }
    }

    void serialize() {
        makeJSONObject("unitCount", g_UnitCount,
                       "spawnPoint", spawnPoint).saveJSON(g_worldPath ~ "/game.json");

        worldState.serialize();
    }

    void render(float deltaT) {
        if(renderer is null) return;
        renderer.render(deltaT, worldState.getDayTime());
    }

    WorldState getWorld() {
        return worldState;
    }

    Renderer getRenderer() {
        return renderer;
    }

    SceneManager getSceneManager() {
        return sceneManager;
    }

    Camera getCamera() {
        return camera;
    }

    Unit getActiveUnit() {
        return activeUnit;
    }

    void setActiveUnit(Unit u) {
        activeUnit = u;
        activeUnitPos = u.pos;
    }

    void setActiveUnitPos(UnitPos pos) {
        if(activeUnit is null) return;
        activeUnitPos = pos;
    }

    void damageTile(TilePos tp, int damage) {
        client.sendCommand(text("DamageTile ", tp.value.x, " ", tp.value.y, " ", tp.value.z, " ", damage));
        msg("damageTile: Implement again, send command over comm channel");
    }

    mixin ServerModule server;
    mixin ClientModule client;

}



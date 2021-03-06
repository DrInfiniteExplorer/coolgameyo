﻿
module game;


import std.algorithm;
import std.conv;
import std.exception;
import std.math;
import std.socket;
import std.stdio;
import std.string;

version(Windows) import core.sys.windows.windows;

//import derelict.sdl2.sdl;

import ai.patrolai;
import ai.test;

import clan;
import clans;
import gaia : Gaia;
import commands : Commands;

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

//import changes.changelist;
import main;
import modules.ai;
import modules.path;
import network.all;
import cgy.util.pos;
import scheduler : scheduler;
import scene.scenemanager;
import settings;
import cgy.util.statistics;

import tiletypemanager;

import playerinformation;
import unittypemanager;
import unit;
import cgy.util.filesystem;
import cgy.util.json : fromJSON;
import cgy.util.util;
import worldstate.worldstate;
import changes.worldproxy;
import changes.changelist;
//import worldgen.worldgen;
import worldgen.maps;

struct Game {

    WorldMap worldMap;
    private WorldState worldState;

    ubyte[] receiveBuffer;
    int send_index;

    private bool isClient;
    private bool isServer;

    private AIModule aiModule;
    private Camera camera;
    private PathModule pathModule;
    private Renderer renderer;
    private SceneManager sceneManager;
    private TileGeometry tileGeometry;
    private TileTextureAtlas atlas;

    Commands commands;
    vec2i spawnPoint;

    private bool destroyed;
    @disable this(this);
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


    void init(bool host) {
        isServer = host;

        mixin(LogTime!("GameInit"));
        if (!isServer) {
            atlas = new TileTextureAtlas; // HACK
            //TODO: Find out what the above comment indicates.
        }
        tileTypeManager.init(atlas);
        entityTypeManager.init();
        unitTypeManager.init();
        
        if(!isServer) {
            sceneManager = new SceneManager();
        }

        worldMap = new WorldMap();
        worldMap.loadWorld(g_worldPath);
        worldState = new WorldState(worldMap, sceneManager);

        scheduler.init();
        scheduler.registerModule(Clans());

        if(isServer) {
            pathModule = new PathModule;
            aiModule = new AIModule(pathModule, worldState);
            scheduler.registerModule(pathModule);
            scheduler.registerModule(aiModule);
            commands = new Commands(worldState);
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

    UnitPos topOfTheWorld(TileXYPos xy) {
        auto top = (worldState.getTopTilePos(xy).value + vec3i(0, 0, 1)).TilePos;
        auto ret = top.toUnitPos();
        return ret;
    }
    private void populateWorld() {
        loadJSON(g_worldPath ~ "/start.json")["startPos"].unJSON(spawnPoint);


        auto proxy = worldState._worldProxy;

        auto clan = newClan(worldState);
        scope(exit) delete clan;
        proxy.createClan(clan);

        auto unit = newUnit();
        scope(exit) delete unit;
        auto unitPos = topOfTheWorld(spawnPoint.TileXYPos);
        unit.pos = unitPos;
        unit.type = unitTypeManager.byName("dwarf");
        unit.clan = clan;
        proxy.createUnit(unit, false);

        auto tree = newEntity("tree01");
        scope(exit) delete tree;
        auto treePos = topOfTheWorld((spawnPoint+vec2i(10,10)).TileXYPos).value.EntityPos;
        tree.pos = treePos;
        tree.clan = Gaia();
        tree.createTreeLikeEntity(proxy, 1);
        proxy.createEntity(tree);
        /*

        // HalfWorldSize_xy
        Unit addUnitAtPos()(vec2i pos) {
            auto xy = TileXYPos(pos);
            auto u = newUnit();
            u.pos = topOfTheWorld(xy);
            u.type = unitTypeManager.byName("dwarf");
            clan.addUnit(u);
            return u;
        }

        auto uu = addUnitAtPos(spawnPoint);
        activeUnit = uu;
        worldState._worldProxy.createUnit(uu);
        */

        //auto clan = newClan(worldState);

        auto workerUnit = newUnit();
        scope(exit) delete workerUnit;
        auto workerUnitPos = topOfTheWorld(spawnPoint.TileXYPos);
        workerUnit.pos = workerUnitPos;
        workerUnit.type = unitTypeManager.byName("dwarf");
        workerUnit.clan = clan;

        proxy.createUnit(workerUnit, false);
    } 

    void loadGame() {
        scheduler.deserialize();
        scheduler.start(g_maxThreadCount);
        Log("Server running!");
    }

    void connect(string host) {
        //client.initModule(host);
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
            auto val = loadJSON(g_worldPath ~ "/game.json");
            val["unitCount"].unJSON(g_UnitCount);
            val["spawnPoint"].unJSON(spawnPoint);
        }
        if(!isServer) {
            auto top = worldState.getTopTilePos(TileXYPos(spawnPoint));
            auto spawn = top.value.convert!double;
            camera.setPosition(spawn + vec3d(0, 0, 20));
            camera.setTargetDir(vec3d(1.0, 0.0,-1.0));
        }
    }

    void serialize() {
        auto val = JSONValue([
            "unitCount" :  g_UnitCount.toJSON,
            "spawnPoint" : spawnPoint.toJSON]);
        std.file.write(g_worldPath ~ "/game.json", val.toString);

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

    Unit        activeUnit;
    UnitPos     activeUnitPos;
    uint        activeUnitId;

    Unit getActiveUnit() {
        if(activeUnit) return activeUnit;
        if(activeUnitId) {
            activeUnit = Clans().getUnitById(activeUnitId);
        }
        if(activeUnit) {
            setActiveUnitPos(activeUnit.pos);
        }
        return activeUnit;
    }

    void setActiveUnit(uint id) {
        if(activeUnitId != id) {
            activeUnit = null; // Derp herp lerp?
        }
        activeUnitId = id;
    }
    /*
    void setActiveUnit(Unit u) {
        activeUnit = u;
        activeUnitPos = u.pos;
    }
    */

    void setActiveUnitPos(UnitPos pos) {
        if(activeUnit is null) return;
        activeUnitPos = pos;
    }

    void damageTile(TilePos tp, int damage) {
        client.sendCommand(text("DamageTile ", tp.value.x, " ", tp.value.y, " ", tp.value.z, " ", damage));
    }

    void designateTiles(string designation, bool set, vec3i start, vec3i size) {
        client.sendCommand(text("Designate ", designation, " ", set ? "set" : "clear", " ",
                                start.x, " ", start.y, " ", start.z, " ", 
                                size.x, " ", size.y, " ", size.z));
    }


    mixin ServerModule server;
    mixin ClientModule client;

}

__gshared Game game;



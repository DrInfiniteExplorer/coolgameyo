
module game;

import core.thread;

import std.algorithm;
import std.array;
import std.concurrency;
import std.conv;
import std.exception;
import std.math;
import std.stdio;
import std.string;

version(Windows) import std.c.windows.windows;

import derelict.sdl.sdl;

import graphics.ogl;
import graphics.camera;
import graphics.font;
import graphics.renderer;
import graphics.texture;

import graphics.debugging;

import scene.scenemanager;


import ai.patrolai;
import ai.test;

import clan;
import heightsheets.heightsheets;
import json;
//import changes.changelist;
import graphics.tilegeometry;
import graphics.tilerenderer;
import modules.ai;
import modules.path;
import pos;
import scheduler;
import statistics;
import tiletypemanager;
import entitytypemanager;
import unittypemanager;
import unit;
import util.util;
import util.filesystem;
import worldstate.worldstate;
//import worldgen.worldgen;
import worldgen.maps;

import std.socket;
import clientnetworking;

import settings;

string SDLError() { return to!string(SDL_GetError()); }

class Game{

    private WorldMap            worldMap;
    private WorldState          worldState;

    private bool            isClient;
    private bool            isServer;
    private bool            isWorker;

    private Camera              camera;
    private Renderer            renderer;
    private SceneManager        sceneManager;
    private TileGeometry        tileGeometry;
    private Scheduler           scheduler;
    private TileTextureAtlas    atlas;
    private TileTypeManager     tileTypeManager;
    private EntityTypeManager   entityTypeManager;
    private UnitTypeManager     unitTypeManager;
    private PathModule          pathModule;
    private AIModule            aiModule;

    private Unit               activeUnit; //TODO: Find out when this unit dies, and tell people.



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
    private void init(string worldName) {
        mixin(LogTime!("GameInit"));
        if (isClient) {
            atlas = new TileTextureAtlas; // HACK
            //TODO: Find out what the above comment indicates.
        }
        tileTypeManager = new TileTypeManager(atlas);
        entityTypeManager = new EntityTypeManager();
        unitTypeManager = new UnitTypeManager();
        sceneManager = new SceneManager();

        worldMap = new WorldMap(worldName);
        worldState = new WorldState(worldMap, tileTypeManager, entityTypeManager, unitTypeManager, sceneManager);

        assert (isWorker, "otherwise wont work lol (maybe)");

        scheduler = new Scheduler(worldState);
        pathModule = new PathModule;
        aiModule = new AIModule(pathModule, worldState);
        scheduler.registerModule(pathModule);
        scheduler.registerModule(aiModule);

        if (isClient) {
            camera = new Camera();
            //The renderer also needs to be created in the main thread, it loads shaders and stuff.
            //Mainly all in this block of code actually :)
            camera.setPosition(vec3d(-2, -2, 20));
            camera.setTarget(vec3d(0, 0, 20));
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
        //This line needs to be moved elsewhere, if we want to do loading in a different thread.
        Tid mainThreadTid = locate("Main thread"); // This is set in main.d : Main.this()
        send(mainThreadTid, "finishInit"); //This will be detected by the main loop, which calls game.loadDone
        scheduler.start();        
    }

    //This is called when the main thread is notified that the loading thread is done loading. We upload gpu stuff here.
    void loadDone() {
        if (isClient) {
            renderer.init();
            msg("move atlas.upload(); //About 0 ms to renderer.init");
        }            
        initCallback(); //Call the registered 'tell me when your finished starting the game'-callback here.
    }

    void populateWorld(vec2i startPos) {

        g_UnitCount = 0;

        UnitPos topOfTheWorld(TileXYPos xy) {
            auto top = worldState.getTopTilePos(xy);
            msg("top: ", top);
            auto ret = top.toUnitPos();
            ret.value.Z += 1;
            msg("ret: ", ret);
            return ret;
        }

        auto clan = newClan(worldState);

        // halfWorldSize_xy
        auto offset = startPos;
        Unit addUnitAtRelativePos(bool relative = false)(int x, int y) {
            auto xy = TileXYPos(vec2i(x,y) + offset);
            auto u = newUnit();
            u.pos = topOfTheWorld(xy);
            u.type = worldState.unitTypeManager.byName("dwarf");
            clan.addUnit(u);
            return u;
        }

        auto u = addUnitAtRelativePos(3,-20);
        auto uu = addUnitAtRelativePos(3,3);

        u.ai = new TestAI(u);

        activeUnit = uu;


        // following is retarded code, ETC :d
        EntityPos topOfTheWorld2(TileXYPos xy) {
            auto top = worldState.getTopTilePos(xy);
            msg("top: ", top);
            auto ret = top.toEntityPos();
            ret.value.Z += 1;
            msg("ret: ", ret);

            return ret;
        }

        /*
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

    void newGameThread(vec2i startPos, string worldName) {
        init(worldName);
        populateWorld(startPos);
        camera.setPosition(vec3d(0, 0, 0));
        camera.setTarget(vec3d(0, 1, 0));
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

    void loadGameThread(string worldName) {
        init(worldName);
        deserialize();
        finishInit();        
    }

    //TODO: Move to better place
    void delegate() initCallback = null;

    void newGame(vec2i startPos, string worldName, void delegate() onDone) {
        initCallback = onDone;
        static void newGameThreadStarter(shared Game g, vec2i startPos, string worldName) {
            try {
                Game game = cast(Game)g;
                game.newGameThread(startPos, worldName);
            } catch (Throwable o) {
                msg("Thread exception!\n", o.toString());
                version(Windows) {
                    MessageBoxA(null, cast(char *)toStringz(o.toString()),
                            "Error", MB_OK | MB_ICONEXCLAMATION);
                }
            }
        }        
        spawn(&newGameThreadStarter, cast(shared)this, startPos, worldName);
    }
    void loadGame(string name, void delegate() onDone) {
        string saveDir = "saves/" ~ name;
        if (exists("saves/current")) {
            rmdir("saves/current");
        }
        //Need to implement a recursive copy function, in util, perhaps?
        util.filesystem.copy(saveDir, "saves/current");

        initCallback = onDone;
        static void loadGameThreadStarter(shared Game g, shared string s) {
            try{
                Game game = cast(Game)g;
                game.loadGameThread(cast(string)s);
            } catch (Throwable o) {
                msg("Thread exception!\n", o.toString());
                version(Windows) {
                    MessageBoxA(null, cast(char *)toStringz(o.toString()),
                            "Error", MB_OK | MB_ICONEXCLAMATION);
                }
            }
        }        
        spawn(&loadGameThreadStarter, cast(shared)this, cast(shared)name);
    }

    //Called in loading thread.
    private void deserialize() {

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



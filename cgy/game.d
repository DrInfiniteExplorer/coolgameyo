
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
import clan;
import jkla;
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
import world.world;
//import worldgen.worldgen;
import worldgen.newgen;

import std.socket;
import clientnetworking;

import settings;

string SDLError() { return to!string(SDL_GetError()); }

class Game{

    private World           world;


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

        tileGeometry.destroy();
        msg("Move atlas.destroy(); to renderer.destroy");
        renderer.destroy();
        world.destroy();
        aiModule.destroy();
        sceneManager.destroy();

        destroyed = true;
    }


    //This and finishInit are run in the thread which becomes the scheduler thread
    private void init(WorldGenParams worldParams) {
        mixin(LogTime!("GameInit"));
        if (isClient) {
            atlas = new TileTextureAtlas; // HACK
            //TODO: Find out what the above comment indicates.
        }
        tileTypeManager = new TileTypeManager(atlas);
        entityTypeManager = new EntityTypeManager();
        unitTypeManager = new UnitTypeManager();
        sceneManager = new SceneManager();
        world = new World(worldParams, tileTypeManager, entityTypeManager, unitTypeManager, sceneManager);
        assert (isWorker, "otherwise wont work lol (maybe)");

        scheduler = new Scheduler(world);
        pathModule = new PathModule;
        aiModule = new AIModule(pathModule, world);
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
            tileGeometry = new TileGeometry(world, tileRenderer);
            auto jkla = new JklA(world);
            renderer = new Renderer(camera, atlas, tileRenderer, sceneManager, jkla);
            scheduler.registerModule(tileGeometry);
            scheduler.registerModule(jkla);
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

    void populateWorld() {

        g_UnitCount = 0;

        UnitPos topOfTheWorld(TileXYPos xy) {
            auto top = world.getTopTilePos(xy);
            msg("top: ", top);
            auto ret = top.toUnitPos();
            ret.value.Z += 1;
            msg("ret: ", ret);
            return ret;
        }

        auto clan = newClan(world);

        auto xy = TileXYPos(vec2i(3,-20));
        xy.value += halfWorldSize_xy;
        auto u = newUnit();
        u.pos = topOfTheWorld(xy);
        u.type = world.unitTypeManager.byName("dwarf");
        //u.pos.value.Z += 1;

        clan.addUnit(u);

        /*
        foreach(idx ; 0 .. 1000) {
            float ratio = cast(float)idx / 1000.0f;
            float x = sin(ratio * 2 * 2 * PI);
            float y = cos(ratio * 2 * 2 * PI);
            float dist = 50 * ratio;
            x *= dist;
            y *= dist;
            auto xy = TileXYPos(vec2i(cast(int)x, cast(int)y));
            xy.value += halfWorldSize_xy;
            auto u = newUnit();
            u.pos = topOfTheWorld(xy);
            u.pos.value.X = x + halfWorldSize_xy.X;
            u.pos.value.Y = y + halfWorldSize_xy.Y;
            u.type = world.unitTypeManager.byName("dwarf");
            clan.addUnit(u);

        }
        */


        //world.addUnit(u);

        msg("u.pos == ", u.pos);

        auto uu = newUnit();
        auto xyy = TileXYPos(vec2i(3,3));
        xyy.value += halfWorldSize_xy;
        uu.pos = topOfTheWorld(xyy);
        uu.type = world.unitTypeManager.byName("dwarf");

        clan.addUnit(uu);


        //world.addUnit(uu);
        //auto goal = UnitPos(u.pos.value + vec3d(-30, 0, 0));
        auto goal = uu.pos;
        //NO AI FOR NO PATHABLENESS WITH NEW RANDOMMAPNESS
        //u.ai = new PatrolAI(u, goal, pathModule);
        //goal.value.Z += 1;
        //addAABB(goal.tilePos.getAABB());
        //u.ai = new DwarfAI(u);

        activeUnit = uu;


        EntityPos topOfTheWorld2(TileXYPos xy) {
            auto top = world.getTopTilePos(xy);
            msg("top: ", top);
            auto ret = top.toEntityPos();
            ret.value.Z += 1;
            msg("ret: ", ret);

            return ret;
        }

        xy = TileXYPos(vec2i(1,5));
        xy.value += halfWorldSize_xy;
        auto o = newEntity();
        o.pos = topOfTheWorld2(xy);
        o.type = world.entityTypeManager.byName("tree");
        world.addEntity(o);
        msg("o.pos == ", o.pos);
        xy = TileXYPos(vec2i(5,1));
        xy.value += halfWorldSize_xy;
        o = newEntity();
        o.pos = topOfTheWorld2(xy);
        o.type = world.entityTypeManager.byName("shrubbery");
        world.addEntity(o);
        msg("o.pos == ", o.pos);
    } 

    void newGameThread(WorldGenParams worldParams) {
        init(worldParams);
        populateWorld();
        camera.setPosition(vec3d(0, 0, 0));
        camera.setTarget(vec3d(0, 1, 0));
        {
            mixin(LogTime!("InitialHeightmaps"));
            world.generateAllHeightmaps();
        }
        {
            mixin(LogTime!("InitialFloodFill"));            
            world.floodFillSome(1_000_000);
        }
        finishInit();
    }

    void loadGameThread(string name) {
        WorldGenParams worldParams;
        init(worldParams);
        deserialize();
        finishInit();        
    }

    //TODO: Move to better place
    void delegate() initCallback = null;

    void newGame(WorldGenParams worldParams, void delegate() onDone) {
        if (exists("saves/current")) {
            rmdir("saves/current");
        }
        initCallback = onDone;
        static void newGameThreadStarter(shared Game g, shared WorldGenParams p) {
            try {
                Game game = cast(Game)g;
                game.newGameThread(cast(WorldGenParams)p);
            } catch (Throwable o) {
                msg("Thread exception!\n", o.toString());
                version(Windows) {
                    MessageBoxA(null, cast(char *)toStringz(o.toString()),
                            "Error", MB_OK | MB_ICONEXCLAMATION);
                }
            }
        }        
        spawn(&newGameThreadStarter, cast(shared)this, cast(shared)worldParams);
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

        world.deserialize();

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
        activeUnit = world.getUnitFromId(activeUnitId);

    }

    void serializeAll(void delegate() andThen) {
        void serialize() {
            //private World           world; Tas hand om av scheduler.
            //private bool            isClient;
            //private bool            isServer;
            //private bool            isWorker;

            //Spara position för kameran?
            //private Camera              camera;

            //Behöver inte sparas. Eller? Kan göra det, för snabb laddning av atlas, och flera 'moddar' igång samtidigt.
            //private TileTextureAtlas    atlas;
            //private TileTypeManager     tileTypeManager;    

            //private Unit               activeUnit; //TODO: Find out when this unit dies, and tell people.
            auto activeUnit = Value(activeUnit.unitId);
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

    World getWorld() {
        return world;
    }

    Renderer getRenderer() {
        return renderer;
    }

    Scheduler getScheduler() {
        return scheduler;
    }

    void render(long usecs) {
        if(renderer is null) return;
        renderer.render(usecs, world.getDayTime());
    }

    mixin NetworkCode; // from clientnetworking.d
}




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

    private Camera            camera;
    private Renderer          renderer;
    private Scheduler         scheduler;
    private TileTextureAtlas  atlas;
    
    private Unit*             activeUnit; //TODO: Find out when this unit dies, and tell people.
    
    private bool              useCamera = true;
    
    /+
    StringTexture     f1, f2, f3, f4, fps, tickTime, renderTime;
    StringTexture     unitInfo, selectedInfo;
    +/

    private bool possesedActive = true;
    private bool _3rdPerson = false;

    this(bool serv, bool clie, bool work) {
        //TODO: Move world-creation etc out of here, and put in init-function instead.
        //We might want to load stuff, so worldgen-settings for example should be 
        //passed elsewhere.
        isServer = serv;
        isClient = clie;
        isWorker = work;

        if (isClient) {
            msg("Initializing client stuff");
            scope (success) msg("Done with client stuff");

            atlas = new TileTextureAtlas; // HACK
        }

        auto tileTypeManager = new TileTypeManager(atlas);//parseGameData();
        WorldGenParams worldParams;
        world = new World(worldParams, tileTypeManager);
        assert (isWorker, "otherwise wont work lol (maybe)");
        //TODO: Make fix so that stuff doesn't lag when using non-1 value for num o threads.
        scheduler = new Scheduler(world);

        auto pathModule = new PathModule;
        auto aiModule = new AIModule(pathModule, world);
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

        UnitPos topOfTheWorld(TileXYPos xy) {
            auto top = world.getTopTilePos(xy);
            msg("top: ", top);
            auto ret = top.toUnitPos();
            if (world.getTile(top).halfstep) {
                ret.value.Z += 0.5;
            } else {
                ret.value.Z += 1;
            }
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

        camera.setPosition(vec3d(0, 0, 0));
        camera.setTarget(vec3d(0, 1, 0));

        world.floodFillSome(1_000_000);
        //auto goal = UnitPos(u.pos.value + vec3d(-30, 0, 0));
        auto goal = uu.pos;
        //NO AI FOR NO PATHABLENESS WITH NEW RANDOMMAPNESS
        //u.ai = new PatrolAI(u, goal, pathModule);
        goal.value.Z += 1;
        addAABB(goal.tilePos.getAABB());
        //u.ai = new DwarfAI(u);
        
        activeUnit = uu;

        scheduler.start();
    }
    
    private bool destroyed;
    ~this() {
        enforce(destroyed, "Game.destroyed not called!");
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

    void parseGameData() {
        if (isClient) {
            /+
            font = new Font("fonts/courier");
            f1 = new StringTexture(font);
            f2 = new StringTexture(font);
            f3 = new StringTexture(font);
            f4 = new StringTexture(font);
            fps = new StringTexture(font);
            tickTime = new StringTexture(font);
            renderTime = new StringTexture(font);
            unitInfo = new StringTexture(font);
            selectedInfo = new StringTexture(font);

            f1.setPositionI(vec2i(0, 0));
            f2.setPositionI(vec2i(0, 1));
            f3.setPositionI(vec2i(0, 2));
            f4.setPositionI(vec2i(0, 3));
            fps.setPositionI(vec2i(0, 4));
            tickTime.setPositionI(vec2i(30, 0));
            renderTime.setPositionI(vec2i(30, 1));
            unitInfo.setPositionI(vec2i(0, 5));
            selectedInfo.setPositionI(vec2i(0, 6));

            f1.setText("polygon fill:" ~ (renderSettings.renderWireframe? "Wireframe":"Fill"));
            f2.setText(useCamera ? "Camera active" : "Camera locked");
            f3.setText("Mipmapppinngggg!! (press f3 to togggeleee");
            f4.setText("VSync:" ~ (renderSettings.disableVSync? "Disabled" : "Enabled"));
            fps.setText("No fps calculted yet");
            +/
        }

/*        auto sys = new TileTypeManager;

        enum f = "textures/001.png";
        if(isClient) atlas.addTile(f, vec2i(16, 0)); //Makes uninitialized tiles show the notiles-tile.

        TileType mud = new TileType;
        if (isClient) {
            mud.textures.side   = atlas.addTile(f);
            mud.textures.top    = atlas.addTile(f, vec2i(0, 16));
            mud.textures.bottom = atlas.addTile(f, vec2i(0, 32));
        }
        mud.transparent = false;
        mud.name = "mud";

        TileType rock = new TileType;
        if (isClient) {
            int x = 200;
            rock.textures.side   = atlas.addTile(f,
                    vec2i(0, 0), vec3i(x,x,x));
            rock.textures.top    = atlas.addTile(f,
                    vec2i(0, 16), vec3i(x,x,x));
            rock.textures.bottom = atlas.addTile(f,
                    vec2i(0, 32), vec3i(x,x,x));
        }
        rock.transparent = false;
        rock.name = "rock";

        TileType water = new TileType;
        if (isClient) {
            water.textures.side   = atlas.addTile(f,
                    vec2i(0, 0), vec3i(0,0,255));
            water.textures.top    = atlas.addTile(f,
                    vec2i(0, 16), vec3i(0,0,255));
            water.textures.bottom = atlas.addTile(f,
                    vec2i(0, 32), vec3i(0,0,255));
        }
        water.transparent = false;
        water.name = "water";

        sys.add(mud);
        sys.add(rock);
        sys.add(water);

        return sys;*/
    }

    void runServer() {
        // set up network interface...? D:
        while (true) {
            //msg("Server loop!");
            Thread.sleep(dur!"seconds"(1));
        }
    }
    
    void render() {
        renderer.render();
    }

    void updateGui() {
        string str = to!string(1_000_000 / renderer.frameAvg);
        /+
        fps.setText("FPS: " ~str);

        str = to!string(renderer.frameAvg / 1000);
        renderTime.setText("Frame time: " ~ str);

        str = to!string(scheduler.frameAvg / 1000);
        tickTime.setText("tick time: " ~ str);
        
        string playerPos = "Camera position: " ~ to!string(camera.getPosition());
        unitInfo.setText(playerPos);
        +/

    }

    long then = 0;

    void stepMipMap() {
        int cnt =   (renderSettings.textureInterpolate ? 1 : 0) +
                    (renderSettings.mipLevelInterpolate ? 2 : 0);
        cnt = (cnt+1)%4;
        renderSettings.textureInterpolate = (cnt%2 != 0);
        renderSettings.mipLevelInterpolate = (cnt > 1);
        atlas.setMinFilter(renderSettings.mipLevelInterpolate, renderSettings.textureInterpolate);
        string tmp;
        switch(cnt){
            default:
            case 0:
                tmp = "GL_NEAREST_MIPMAP_NEAREST"; break;
            case 1:
                tmp = ("GL_LINEAR_MIPMAP_NEAREST"); break;
            case 2:
                tmp = ("GL_NEAREST_MIPMAP_LINEAR"); break;
            case 3:
                tmp = ("GL_LINEAR_MIPMAP_LINEAR"); break;
        }
        msg(tmp);

        /+
        f3.setText(tmp);
        +/
    }

/+    
    void onKey(SDL_KeyboardEvent event){
        auto key = event.keysym.sym;
        auto down = event.type == SDL_KEYDOWN;
        keyMap[key] = down;
        if(key == SDLK_F1 && down){
            renderSettings.renderWireframe ^= 1;
            /+
            f1.setText("polygon fill:" ~ (renderSettings.renderWireframe? "Wireframe":"Fill"));
            +/
        }
        if(key == SDLK_F2 && down) {
            useCamera ^= 1;
            /+
            f2.setText(useCamera ? "Camera active" : "Camera locked");
            +/
        }
        if(key == SDLK_F3 && down) stepMipMap();
        if(key == SDLK_F4 && down) {
            renderSettings.disableVSync ^= 1;
            version (Windows) {
                setVSync(!renderSettings.disableVSync);
                
            } else {
                msg("Cannot poke with vsync unless wgl blerp");
            }
            /+
            f4.setText("VSync:" ~ (renderSettings.disableVSync? "Disabled" : "Enabled"));
            +/
        }
        if(key == SDLK_F5 && down) possesedActive ^= 1;
        if(key == SDLK_F6 && down) _3rdPerson ^= 1;
    }
+/    

    
}








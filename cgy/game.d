import core.thread;

import std.algorithm;
import std.array;
import std.concurrency;
import std.conv;
import std.exception;
import std.datetime;
import std.stdio;

version(Windows){
    import std.c.windows.windows;
}

import derelict.sdl.sdl;

import graphics.ogl;
import graphics.font;
import graphics.camera;
import graphics.renderer;
import graphics.texture;

import tilesystem;
import world;
import scheduler;
import pos;
import util;
import unit;

string SDLError() { return to!string(SDL_GetError()); }

class Game{

    World           world;


    bool            isClient;
    bool            isServer;
    bool            isWorker;

    ushort          middleX;
    ushort          middleY;

    SDL_Surface*      surface;
    Camera            camera;
    Renderer          renderer;
    Scheduler         scheduler;
    TileTextureAtlas  atlas;
    Font              font;
    bool[SDLK_LAST]   keyMap;
    bool              useCamera;

    StringTexture     f1, f2, f3, fps, tickTime, renderTime;

    this(bool serv, bool clie, bool work) {
        isServer = serv;
        isClient = clie;
        isWorker = work;

        if (isClient) {
            writeln("Initializing client stuff");
            scope (success) writeln("Done with client stuff");

            middleX = cast(ushort)renderSettings.windowWidth/2;
            middleY = cast(ushort)renderSettings.windowHeight/2;

            enforce(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_NOPARACHUTE) == 0,
                    SDLError());

            SDL_GL_SetAttribute(SDL_GL_RED_SIZE,        8);
            SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE,      8);
            SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE,       8);
            SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE,      8);

            SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE,      32);
            SDL_GL_SetAttribute(SDL_GL_BUFFER_SIZE,     32);
            SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER,      1);

            //Antialiasing. now off-turned.
            //Apparently this AA only works on edges and not on surfaces, so turned off for now.
            SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS,  0);
            SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES,  16);

            surface = enforce(SDL_SetVideoMode(renderSettings.windowWidth, renderSettings.windowHeight,
                                               32, SDL_HWSURFACE | SDL_GL_DOUBLEBUFFER | SDL_OPENGL),
                              "Could not set sdl video mode (" ~ SDLError() ~ ")");
            initOpenGL();
            atlas = new TileTextureAtlas; // HACK
        }

        auto tilesys = parseGameData();
        world = new World(tilesys);
        assert (isWorker, "otherwise wont work lol (maybe)");
        scheduler = new Scheduler(world, 1);

        if (isClient) {
            camera = new Camera();
            renderer = new Renderer(world, scheduler, camera);
            renderer.atlas = atlas;

            atlas.upload();
            camera.setPosition(vec3d(-2, -2, 20));
            camera.setTarget(vec3d(0, 0, 20));


        }

        auto xy = tileXYPos(vec2i(10,10));
        auto u = new Unit;
        u.pos = world.getTopTilePos(xy).toUnitPos();
        u.pos.value.Z += 1;
        world.addUnit(u);

        auto uu = new Unit;
        auto xyy = tileXYPos(vec2i(127,127));
        uu.pos = world.getTopTilePos(xyy).toUnitPos();
        uu.pos.value.Z += 1;
        world.addUnit(uu);


        u.destination = uu.pos.value;
        u.ticksUntilArrived = 30 * 60; // 60 seconds
        //world.floodFillVisibility(xy);
        /*
        foreach(sector; world.sectorList){
            world.notifySectorLoad(sector.sectorNum);
        }
        */
    }

    TileSystem parseGameData() {
        font = new Font("fonts/courier");
        f1 = new StringTexture(font);
        f2 = new StringTexture(font);
        f3 = new StringTexture(font);
        fps = new StringTexture(font);
        tickTime = new StringTexture(font);
        renderTime = new StringTexture(font);

        f1.setPositionI(vec2i(0, 0));
        f2.setPositionI(vec2i(0, 1));
        f3.setPositionI(vec2i(0, 2));
        fps.setPositionI(vec2i(0, 3));
        tickTime.setPositionI(vec2i(30, 0));
        renderTime.setPositionI(vec2i(30, 1));

        f1.setText("polygon fill:" ~ (renderSettings.renderWireframe? "Wireframe":"Fill"));
        f2.setText(useCamera ? "Camera active" : "Camera locked");
        f3.setText("Mipmapppinngggg!! (press f3 to togggeleee");
        fps.setText("No fps calculted yet");

        auto sys = new TileSystem;

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
            rock.textures.side   = atlas.addTile(f,
                    vec2i(0, 0), vec3i(100,100,100));
            rock.textures.top    = atlas.addTile(f,
                    vec2i(0, 16), vec3i(100,100,100));
            rock.textures.bottom = atlas.addTile(f,
                    vec2i(0, 32), vec3i(100,100,100));
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

        return sys;
    }

    void start() {
        if (isClient) {
            if (isServer) {
                spawn(function(shared Game g) {
                        setThreadName("Server thread");
                        (cast(Game)g).runServer();
                        }, cast(shared)this);
            } else {
                assert (false, "wherp!");
            }

            runClient();
        } else {
            runServer();
        }
    }

    void runServer() {
        // set up network interface...? D:
        while (true) {
            writeln("Server loop!");
            Thread.sleep(dur!"seconds"(1));
        }
    }

    void runClient() {
        assert (isClient);
        auto exit = false;
        SDL_Event event;
        while (!exit) {

            //writeln("mainloop!");
            //auto task = scheduler.getTask();
            //task.run(world);


            while (SDL_PollEvent(&event)) {
                switch (event.type) {
                    case SDL_QUIT:
                        exit = true; break;
                    case SDL_KEYDOWN:
                    case SDL_KEYUP:
                        onKey(event.key);
                        break;
                    case SDL_MOUSEMOTION:
                        mouseMove(event.motion);
                        break;
                    case SDL_MOUSEBUTTONDOWN:
                    case SDL_MOUSEBUTTONUP:
                        break;
                    default:
                }

                version (Windows) {
                    if (event.key.keysym.sym == SDLK_F4
                            && (event.key.keysym.mod == KMOD_LALT
                                || event.key.keysym.mod == KMOD_RALT)) {
                        exit=true;
                    }
                }
                if (event.key.keysym.sym == SDLK_ESCAPE) exit = true;
            }

            if(useCamera)
                updateCamera(); //Or doInterface() or controlDwarf or ()()()()();

            renderer.render();
            updateGui();
            f1.render();
            f2.render();
            f3.render();
            fps.render();
            renderTime.render();
            tickTime.render();
            SDL_GL_SwapBuffers();
        }
    }

    void updateGui(){
        string str = to!string(1_000_000 / renderer.frameAvg);
        fps.setText("FPS: " ~str);


        str = to!string(renderer.frameAvg / 1000);
        renderTime.setText("Frame time: " ~ str);

        str = to!string(scheduler.frameAvg / 1000);
        tickTime.setText("tick time: " ~ str);

    }

    void updateCamera(){
        if(keyMap[SDLK_a]){ camera.axisMove(-0.1, 0.0, 0.0); }
        if(keyMap[SDLK_d]){ camera.axisMove( 0.1, 0.0, 0.0); }
        if(keyMap[SDLK_w]){ camera.axisMove( 0.0, 0.1, 0.0); }
        if(keyMap[SDLK_s]){ camera.axisMove( 0.0,-0.1, 0.0); }
        if(keyMap[SDLK_SPACE]){ camera.axisMove( 0.0, 0.0, 0.1); }
        if(keyMap[SDLK_LCTRL]){ camera.axisMove( 0.0, 0.0,-0.1); }
    }

    void stepMipMap() {
        int cnt =   (renderSettings.textureInterpolate ? 1 : 0) +
                    (renderSettings.mipLevelInterpolate ? 2 : 0);
        cnt = (cnt+1)%4;
        renderSettings.textureInterpolate = (cnt%2 != 0);
        renderSettings.mipLevelInterpolate = (cnt > 1);
        atlas.setMinFilter(renderSettings.mipLevelInterpolate, renderSettings.textureInterpolate);
        string tmp;
        switch(cnt){
            case 0:
                tmp = "GL_NEAREST_MIPMAP_NEAREST"; break;
            case 1:
                tmp = ("GL_LINEAR_MIPMAP_NEAREST"); break;
            case 2:
                tmp = ("GL_NEAREST_MIPMAP_LINEAR"); break;
            case 3:
                tmp = ("GL_LINEAR_MIPMAP_LINEAR"); break;
        }
        writeln(tmp);

        f3.setText(tmp);
    }

    void onKey(SDL_KeyboardEvent event){
        auto key = event.keysym.sym;
        auto down = event.type == SDL_KEYDOWN;
        keyMap[key] = down;
        if(key == SDLK_F1 && down){
            renderSettings.renderWireframe ^= 1;
            f1.setText("polygon fill:" ~ (renderSettings.renderWireframe? "Wireframe":"Fill"));
        }
        if(key == SDLK_F2 && down) {
            useCamera ^= 1;
            f2.setText(useCamera ? "Camera active" : "Camera locked");
        }
        if(key == SDLK_F3 && down) stepMipMap();

    }

    bool oldUseCamera;
    void mouseMove(SDL_MouseMotionEvent mouse){
        auto x = mouse.x;
        auto y = mouse.y;
        if(x != middleX || y != middleY){
            if(useCamera) {
                SDL_WarpMouse(middleX, middleY);
                if(oldUseCamera) {
                    camera.mouseMove( mouse.xrel,  mouse.yrel);
                }
            }
        }
        oldUseCamera = useCamera;
    }
}

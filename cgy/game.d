import std.stdio;
import std.conv;
import std.exception;

import derelict.sdl.sdl;
import derelict.opengl.gl;
import derelict.devil.il;

version(Windows){
    import std.c.windows.windows;
}

import graphics.camera;
import graphics.renderer;
import graphics.texture;

import world;
import scheduler;
import pos;
import util;
import unit;

string SDLError() { return to!string(SDL_GetError()); }

class Game{
    
    World            world;


    bool            isClient;
    bool            isServer;
    bool            isWorker;

    ushort          width = 800;
    ushort          height = 600;
    ushort          middleX;
    ushort          middleY;

    SDL_Surface*      surface;
    Camera            camera;
    Renderer          renderer;
    Scheduler         scheduler;
    TileTextureAtlas  atlas;
    bool[SDLK_LAST]       keyMap;
    
    this(bool serv, bool clie, bool work){
        isServer = serv;
        isClient = clie;
        isWorker = work;
        world = new World();
        scheduler = new Scheduler(world, 0);

        if(isClient){
            DerelictSDL.load();
            DerelictGL.load();
            DerelictIL.load();
            ilInit();

            middleX = width/2;
            middleY = height/2;

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
            SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS,  0);
            SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES,  2);

            surface = enforce(SDL_SetVideoMode(width, height, 32, SDL_HWSURFACE | SDL_GL_DOUBLEBUFFER | SDL_OPENGL),
                              "Could not set sdl video mode (" ~ SDLError() ~ ")");
 
            renderer = new Renderer(world);
            atlas = new TileTextureAtlas();
            renderer.atlas = atlas;
            camera = new Camera();
            
        }
        parseGameData();

        auto xy = tileXYPos(vec2i(0,0));
        auto u = new Unit;
        u.pos = world.getTopTilePos(xy).toUnitPos();
        u.pos.value.Z += 1;
        world.addUnit(u);

        auto uu = new Unit;        
        auto xyy = tileXYPos(vec2i(127,127));
        uu.pos = world.getTopTilePos(xyy).toUnitPos();
        uu.pos.value.Z += 1;
        world.addUnit(uu);
        //world.floodFillVisibility(xy);
        foreach(sector; world.sectorList){
            world.notifySectorLoad(sector.sectorNum);
        }
    }
    
    void parseGameData(){
        
        
        TileType invalid;
        invalid.transparent = false; //TODO: Make rendersetting.

        TileType air;
        air.transparent = true;
        air.tileName = "air";
        
        TileType mud;
        if(isClient){
            mud.sideTexId     = atlas.addTile("textures/001.png", vec2i(0, 0), vec3i(255, 255, 255));
            mud.topTexId      = atlas.addTile("textures/001.png", vec2i(0, 16), vec3i(255, 255, 255));
            mud.bottomTexId   = atlas.addTile("textures/001.png", vec2i(0, 32), vec3i(255, 255, 255));
        }
        mud.materialId = 0;
        mud.strength = 10;
        mud.transparent = false;
        world.tileTypes ~= [invalid, air, mud];
        
        if(isClient){
            atlas.upload();
        }
    }
    
    
    void run(){
        //driver.beginScene(true, true, SColor(0, 160, 0, 128));
        auto exit = false;
        SDL_Event event;
        while(!exit){
            while(SDL_PollEvent(&event)) {
                switch(event.type){
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
                //Because SDL is ANAL and intercepts alt+f4....
                version(Windows){
                    if(event.key.keysym.sym == SDLK_F4 && (event.key.keysym.mod ==
                        KMOD_LALT || event.key.keysym.mod == KMOD_RALT) ){
                        exit=true;
                    }
                }
            }
            
            updateCamera(); //Or doInterface() or controlDwarf or ()()()()();
            
            renderer.render(camera);
            updateFPS();
            SDL_GL_SwapBuffers();            
        }
    }
    
    int startTime = 0;
    int count = 0;
    void updateFPS(){        
        version(Windows){
            auto now = GetTickCount();
        }
        version(Posix){
            auto now = 1;
        }
        //writeln("DERPTI DERP FPS");
        auto delta = now-startTime;
        count++;
        if(delta > 1000){
            writeln(count);
            startTime =now;
            count = 0;
        }
        
    }
    
    void updateCamera(){
        if(keyMap[SDLK_a]){
            camera.axisMove(-0.1, 0.0, 0.0);
        }
        if(keyMap[SDLK_d]){
            camera.axisMove( 0.1, 0.0, 0.0);
        }
        if(keyMap[SDLK_w]){
            camera.axisMove( 0.0, 0.1, 0.0);
        }
        if(keyMap[SDLK_s]){
            camera.axisMove( 0.0,-0.1, 0.0);
        }
        if(keyMap[SDLK_SPACE]){
            camera.axisMove( 0.0, 0.0, 0.1);
        }
        if(keyMap[SDLK_LCTRL]){
            camera.axisMove( 0.0, 0.0,-0.1);
        }
    }
    
    void onKey(SDL_KeyboardEvent event){
        auto key = event.keysym.sym;
        auto down = event.type == SDL_KEYDOWN;
        keyMap[key] = down;
    }
    
    void mouseMove(SDL_MouseMotionEvent mouse){
        auto x = mouse.x;
        auto y = mouse.y;
        if(x != middleX || y != middleY){
            SDL_WarpMouse(middleX, middleY);
            camera.mouseMove( mouse.xrel,  mouse.yrel);    
        }
    }
        
    //
}

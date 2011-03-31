import std.stdio;
import std.conv;
import std.exception;

import derelict.sdl.sdl;
import derelict.opengl.gl;
import win32.windows;

import world;
import camera;
import renderer;
import scheduler;
import pos;
import util;
import unit;

class Game{
	
	World			world;


	bool			isClient;
	bool			isServer;
	bool			isWorker;

    SDL_Surface*    surface;
	Camera			camera;
	Renderer		renderer;
	Scheduler		scheduler;
	bool			keyMap[256];	
	
	this(bool serv, bool clie, bool work){
		isServer = serv;
		isClient = clie;
		isWorker = work;
		world = new World();
		if(isClient){   
            DerelictSDL.load();
            DerelictGL.load();
            assert(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_NOPARACHUTE) == 0, "SDL creation faileeed!");
            
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
            
            surface = enforce(SDL_SetVideoMode(800, 600, 32, SDL_HWSURFACE | SDL_GL_DOUBLEBUFFER | SDL_OPENGL),
                              "Could not set sdl video mode (create window, gl context etc)");
 
			scheduler = new Scheduler(world, 0);
			renderer = new Renderer(world);
			camera = new Camera();
		}
        
        auto xy = tileXYPos(vec2i(0,0));
        auto u = new Unit;
        u.pos = world.getTopTilePos(xy).toUnitPos();
        u.pos.value.Z += 1;
        world.addUnit(u);

        auto uu = new Unit;        
        auto xyy = tileXYPos(vec2i(128,128));
        uu.pos = world.getTopTilePos(xyy).toUnitPos();
        uu.pos.value.Z += 1;
        world.addUnit(uu);
        world.floodFillVisibility(xy);
        foreach(sector; world.sectorList){
            world.notifySectorLoad(sector.sectorNum);
        }
	}
	
	
	void run(){
        //driver.beginScene(true, true, SColor(0, 160, 0, 128));
        auto exit = false;
        SDL_Event event;
        while(!exit){
            while(SDL_PollEvent(&event)) {
                if(event.type == SDL_QUIT){
                    exit = true;
                }
            }
            renderer.render(camera);
            SDL_GL_SwapBuffers();
            writeln(GetTickCount());
        }
        //driver.endScene();
	}
        
    //camera.mouseMove( dx,  dy);    
}

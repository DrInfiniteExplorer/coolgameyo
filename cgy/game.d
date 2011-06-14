import core.thread;

import std.algorithm;
import std.array;
import std.concurrency;
import std.conv;
import std.exception;
import std.math;
import std.stdio;

import derelict.sdl.sdl;

import graphics.camera;
import graphics.debugging;
import graphics.font;
import graphics.ogl;
import graphics.renderer;
import graphics.texture;

import changelist;
import modules.ai;
import modules.path;
import pos;
import scheduler;
import tilesystem;
import util;
import unit;
import world;

import settings;

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
    bool              useCamera = true;

    FPSControlAI   possesAI;

    StringTexture     f1, f2, f3, f4, fps, tickTime, renderTime;
    StringTexture     unitInfo;

    bool possesedActive = true;
    bool _3rdPerson = false;

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
        //TODO: Make fix so that stuff doesn't lag when using non-1 value for num o threads.
        scheduler = new Scheduler(world);

        auto pathModule = new PathModule;
        auto aiModule = new AIModule(pathModule);
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

        auto xy = TileXYPos(vec2i(10,10));
        auto u = new Unit;
        u.pos = world.getTopTilePos(xy).toUnitPos();
        //u.pos.value.Z += 1;
        world.addUnit(u);

        auto uu = new Unit;
        auto xyy = TileXYPos(vec2i(0,0));
        uu.pos = world.getTopTilePos(xyy).toUnitPos();
        world.addUnit(uu);

        camera.setPosition(vec3d(0, 0, 0));
        camera.setTarget(vec3d(0, 1, 0));

        world.floodFillSome(1_000_000);
        // Commented out for presentation; Dont want stuff crashing :p
        //u.ai = new MoveToAI(uu, 1.0/15.0);

        possesAI = new FPSControlAI(world);
        possesAI.setUnit(uu);


        scheduler.start();
    }

    TileSystem parseGameData() {
        if (isClient) {
            font = new Font("fonts/courier");
            f1 = new StringTexture(font);
            f2 = new StringTexture(font);
            f3 = new StringTexture(font);
            f4 = new StringTexture(font);
            fps = new StringTexture(font);
            tickTime = new StringTexture(font);
            renderTime = new StringTexture(font);
            unitInfo = new StringTexture(font);

            f1.setPositionI(vec2i(0, 0));
            f2.setPositionI(vec2i(0, 1));
            f3.setPositionI(vec2i(0, 2));
            f4.setPositionI(vec2i(0, 3));
            fps.setPositionI(vec2i(0, 4));
            tickTime.setPositionI(vec2i(30, 0));
            renderTime.setPositionI(vec2i(30, 1));
            unitInfo.setPositionI(vec2i(0, 5));

            f1.setText("polygon fill:" ~ (renderSettings.renderWireframe? "Wireframe":"Fill"));
            f2.setText(useCamera ? "Camera active" : "Camera locked");
            f3.setText("Mipmapppinngggg!! (press f3 to togggeleee");
            f4.setText("VSync:" ~ (renderSettings.disableVSync? "Disabled" : "Enabled"));
            fps.setText("No fps calculted yet");
        }

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

            if (useCamera) {
                updateCamera();
            }
            if (possesedActive) {
                updatePossesed();
            }

            rayPick();
            renderer.render();
            updateGui();
            f1.render();
            f2.render();
            f3.render();
            f4.render();
            fps.render();
            renderTime.render();
            tickTime.render();
            unitInfo.render();
            SDL_GL_SwapBuffers();
        }
    }

    void updateGui() {
        string str = to!string(1_000_000 / renderer.frameAvg);
        fps.setText("FPS: " ~str);


        str = to!string(renderer.frameAvg / 1000);
        renderTime.setText("Frame time: " ~ str);

        str = to!string(scheduler.frameAvg / 1000);
        tickTime.setText("tick time: " ~ str);

    }

    void updateCamera() {
        if(keyMap[SDLK_a]){ camera.axisMove(-0.1, 0.0, 0.0); }
        if(keyMap[SDLK_d]){ camera.axisMove( 0.1, 0.0, 0.0); }
        if(keyMap[SDLK_w]){ camera.axisMove( 0.0, 0.1, 0.0); }
        if(keyMap[SDLK_s]){ camera.axisMove( 0.0,-0.1, 0.0); }
        if(keyMap[SDLK_SPACE]){ camera.axisMove( 0.0, 0.0, 0.1); }
        if(keyMap[SDLK_LCTRL]){ camera.axisMove( 0.0, 0.0,-0.1); }
    }

    long then = 0;
    void updatePossesed() { 

        long now = utime();
        float deltaT = (now-then) / 100_000.f;
        then = now;

        double right = 0;
        double fwd = 0;
        if(keyMap[SDLK_a]){ right-=0.2; }
        if(keyMap[SDLK_d]){ right+=0.2; }
        if(keyMap[SDLK_w]){ fwd+=0.2; }
        if(keyMap[SDLK_s]){ fwd-=0.2; }
        if(keyMap[SDLK_SPACE]){
            if(possesAI.onGround){
                possesAI.fallSpeed = 0.55f;
            }
        }
        possesAI.move(right, fwd, 0.f, deltaT);

        auto pos = possesAI.getUnitPos();
        auto dir = camera.getTargetDir();
        if(_3rdPerson) {
            pos -= util.convert!double(dir) * 7.5;
        } else {
            pos += vec3d(0, 0, 1.5);
        }
        camera.setPosition(pos);
        auto rad = atan2(dir.Y, dir.X);
        possesAI.setRotation(rad);
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
        if(key == SDLK_F4 && down) {
            renderSettings.disableVSync ^= 1;
            version (Windows) {
                wglSwapIntervalEXT(renderSettings.disableVSync ? 0 : 1);
            } else {
                writeln("Cannot poke with vsync unless wgl blerp");
            }
            f4.setText("VSync:" ~ (renderSettings.disableVSync? "Disabled" : "Enabled"));
        }
        if(key == SDLK_F5 && down) possesedActive ^= 1;
        if(key == SDLK_F6 && down) _3rdPerson ^= 1;
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
        mousecoords.set(x, y);
    }
    vec2i mousecoords;
    
    void rayPick(){
        vec3d start, dir;
        camera.getRayFromScreenCoords(mousecoords, start, dir);
        Tile tile;
        TilePos tilePos;
        vec3i normal;
        if(0 < world.intersectTile(start, dir, 25, tile, tilePos, normal)){
            if(asdasdasd){
                removeAABB(asdasdasd);
            }
            auto temp = TilePos(tilePos.value);
            aabbd aabb = temp.getAABB();
            aabb.scale(vec3d(1.025f));
            asdasdasd = addAABB(aabb);
        }
        if(dsadsadsa){
            removeLine(dsadsadsa);
        }
        auto pt = start + dir;
        auto _start = start + vec3d(0, 0, 2);
        dsadsadsa = addLine([_start, pt], vec3f(0, 0, 1));
    }    
    int asdasdasd;
    int dsadsadsa;
}


class FPSControlAI : UnitAI, CustomChange {
    Unit* unit;
    //vec3d velocity;
    float fallSpeed;
    bool onGround;
    World world;
    UnitPos oldPosition;

    this(World w) {
        world = w;
    }

    void setUnit(Unit* unit){
        unit.ai = this;
        this.unit = unit;
        fallSpeed = 0.f;
        onGround=false;
        oldPosition = unit.pos;
        //Save old ai?
        //Send data to clients that this unit is possessed!!!!
        // :)
    }



    vec3d collideMove(vec3d pos, vec3d dir, int level=0){
        if (dir == vec3d(0, 0, 0)) { return pos; }
        if (level > 5) {
            writeln("Penix");
            enforce(0, "DIX!");
            return pos;
        }

        auto min = UnitPos(pos).tilePos; min.value -= vec3i(1, 1, 1);
        auto max = min; max.value += vec3i(3, 3, 4);

        bool checkCollision(vec3d pos, vec3d dir, out float minTime, out vec3d minNormal){
            bool didCollide = false;
            minTime = float.max;
            auto aabb = unit.aabb(&pos);
            foreach (rel; RangeFromTo(min.value, max.value)) {
                auto tp = TilePos(rel);
                auto tile = world.getTile(tp);
                auto tileBox = tp.getAABB(tile.halfstep);
                float time;
                vec3d normal;
                if (tile.transparent
                        || !aabb.intersectsWithBox(tileBox, dir, time, normal)) {
                    continue;
                }
                if (isNaN(time)) {
                    minTime = float.nan;
                    writeln("Unit is inside of something. Solve this, like, loop upwards until not collides anylonger. or something.");
                    return true;
                }
                if (time < minTime) {
                    minTime = time;
                    minNormal = normal;
                }
                didCollide = true;
            }
            return didCollide;
        }

        float time = float.max;
        vec3d normal;


        if (!checkCollision(pos, dir, time, normal)) {
            return pos + dir;
        }
        if (isNaN(time)) {
            //enforce(0, "Implement, like move dude upwards until on top, something?");
            //return pos;
            vec3d _pos = pos + vec3d(0, 0, 1);
            vec3d _dir = vec3d(0.0, 0.0, 0.0);
            //while (!checkCollision(_pos, _dir, time, normal)) {
            //    writeln("gay gay gay ", UnitPos(_pos));
            //    _pos.Z += 1;
            //}
            return _pos;
        }
        // We have collided with some box
        //IF CAN STEP STEP
        if (normal.Z == 0) {
            auto stepStart = pos + vec3d(0, 0, unit.stepHeight);
            float stepTime;
            auto stepDir = dir * vec3d(1, 1, 0);
            vec3d stepNormal;
            bool stepCollided = checkCollision(stepStart, dir, stepTime, stepNormal);
            if (!stepCollided) {
                return stepStart + dir;
            }
            if (stepTime < time) {
                time = stepTime;
                pos = stepStart;
                normal = stepNormal;
            }
        } else{
            onGround = true;
        }
        //ELSE Slideee!! :):):)

        // move forward first
        auto newPos = pos + dir * time;
        dir = (1-time) * dir;

        assert (normal.getLengthSQ == 1);

        auto normPart = normal.dotProduct(dir) * normal;
        auto tangPart = dir - normPart;

        assert (tangPart.getLengthSQ() < dir.getLengthSQ());

        return collideMove(newPos, tangPart, level+1);
    }

    //Make sure that it is sent over network, and such!! (like comment below)
    void move(float right, float fwd, float up, float deltaT) {
        immutable origo = vec3d(0, 0, 0);

        onGround = false;
        fallSpeed -= 0.15f * deltaT;
        auto dir = vec3d(fwd, -right, up + fallSpeed) * deltaT;
        dir.rotateXYBy(unit.rotation, origo);
        unit.pos.value = collideMove(unit.pos.value, dir);
        if(onGround){
            fallSpeed = 0.f;
        }
    }

    void setRotation(float rot){
        enforce(unit !is null, "FPSControlAI's unit is null!!");
        unit.rotation = rot;
    }

    vec3d getUnitPos(){
        enforce(unit !is null, "FPSControlAI's unit is null!!");
        return unit.pos.value;
    }

    //This is now mostly used to make a 'real' commit of the movement.
    //Moving the unit would like, break things, kinda, otherwise, and such.
    //How/what to do when networked? Other clients will want to know where it is positioned.
    //Probably send information like "Unit X is player-controlled" to set NetworkControlledAI
    //which'll work kina like this one, i suppose.
    override void tick(Unit* unit, ChangeList changeList){
        assert (unit == this.unit, "Derp! FPSControlAI.unit != unit-parameter in this.tick!");
        changeList.addCustomChange(this);
    }
    
    //Hax used: oldPosition, to make the world produce a delta-pos-value and load sectors
    void apply(World world) {
        auto pos = unit.pos;
        unit.pos = oldPosition;
        oldPosition = pos;
        world.unsafeMoveUnit(unit, pos.value, 1);
        //TODO: Make rotate of units as well? :):):)
    }

}







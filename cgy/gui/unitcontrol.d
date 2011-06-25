

module gui.unitcontrol;

import std.conv;
import std.exception;
import std.math;

import derelict.sdl.sdl;

import ai.posessai;
import game;
import graphics.camera;
import graphics.debugging;
import gui.guisystem.guisystem;
import settings;
import unit;
import world;



class HyperUnitControlInterfaceInputManager : GuiEventDump{

    private Game game;    
    private World world;
    private FPSControlAI possesAI;
    private Camera camera;
    private Unit* unit;

    private bool[SDLK_LAST]   keyMap;    
    private bool _3rdPerson;
    
    private ushort          middleX;
    private ushort          middleY;    
    
    this(Game g) {
        game = g;
        world = game.getWorld();
        camera = game.getCamera();
        setControlledUnit(game.getActiveUnit());

        middleX = cast(ushort)renderSettings.windowWidth/2;
        middleY = cast(ushort)renderSettings.windowHeight/2;
        
    }
    
    private bool destroyed;
    ~this(){
        enforce(destroyed, text(typeof(this).stringof, ".destroy not called!"));
    }    
    void destroy(){
        destroyed = true;
    }
    
    void setControlledUnit(Unit* u) {
        if (unit) {
            auto ai = unit.ai;
            enforce(ai, "Controlled / possessed unit does not have ai? :S");
            enforce(possesAI is ai, "Controlled / possessed unit has wrong ai! :S");
            possesAI.destroy();
        }
        unit = u;
        possesAI = new FPSControlAI(world);
        possesAI.setUnit(unit);
    }
    
    void mouseMove(GuiEvent e){
        auto m = e.mouseMove;
        auto x = m.pos.X;
        auto y = m.pos.Y;
        auto diffX = x - middleX;
        auto diffY = y - middleY;
        if(diffX != 0 || diffY != 0){
                SDL_WarpMouse(middleX, middleY);
                    camera.mouseMove( diffX,  diffY);
        }
        mousecoords.set(x, y);
    }
    vec2i mousecoords;
    
    
    override GuiEventResponse onDumpEvent(GuiEvent e) {
        if (e.type == GuiEventType.MouseMove) {
            mouseMove(e);
            return GuiEventResponse.Accept;
        } else if (e.type == GuiEventType.Keyboard) {
            auto k = e.keyboardEvent;
            auto key = k.SdlSym;
            auto down = k.pressed;
            keyMap[key] = down;            
            return GuiEventResponse.Accept;
        }
        return GuiEventResponse.Ignore;
    }
    
    void tick(float dTime) {
        updatePossesed(dTime);
    }

    void updatePossesed(float dTime) { 
        double right = 0;
        double fwd = 0;
        if(keyMap[SDLK_a]){ right-=0.4; }
        if(keyMap[SDLK_d]){ right+=0.4; }
        if(keyMap[SDLK_w]){ fwd+=0.4; }
        if(keyMap[SDLK_s]){ fwd-=0.4; }
        if(keyMap[SDLK_SPACE]){
            if(possesAI.onGround){
                possesAI.fallSpeed = 0.55f;
            }
        }
        possesAI.move(right, fwd, 0.f, dTime);

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
    
    //Call to update free-flying camera
    void updateCamera() {
        if(keyMap[SDLK_a]){ camera.axisMove(-0.1, 0.0, 0.0); }
        if(keyMap[SDLK_d]){ camera.axisMove( 0.1, 0.0, 0.0); }
        if(keyMap[SDLK_w]){ camera.axisMove( 0.0, 0.1, 0.0); }
        if(keyMap[SDLK_s]){ camera.axisMove( 0.0,-0.1, 0.0); }
        if(keyMap[SDLK_SPACE]){ camera.axisMove( 0.0, 0.0, 0.1); }
        if(keyMap[SDLK_LCTRL]){ camera.axisMove( 0.0, 0.0,-0.1); }
    }
    
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
            aabbd aabb = temp.getAABB(tile.halfstep);
            aabb.scale(vec3d(1.025f));
            asdasdasd = addAABB(aabb);
            /+
            string tileString = "Tile under mouse: " ~ to!string(tilePos);            
            selectedInfo.setText(tileString);
            +/
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



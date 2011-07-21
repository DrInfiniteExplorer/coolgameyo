

module gui.unitcontrol;

import std.conv;
import std.exception;
import std.math;
import std.stdio;

import derelict.sdl.sdl;

import ai.posessai;
import game;
import graphics.camera;
import graphics.debugging;
import graphics.renderer;
import gui.all;
import scheduler;
import settings;
import tiletypemanager;
import unit;
import world;



class HyperUnitControlInterfaceInputManager : GuiEventDump{
    
    private GuiSystem guiSystem;
    private GuiElementText fpsText, tickText, frameTimeText, tickTimeText;

    private Game game;    
    private Renderer renderer;    //This and scheduler only used to get fps / tps info. Make proxy or thing?
    private Scheduler scheduler;
    private World world;
    private FPSControlAI possesAI;
    private Camera camera;
    private Unit* unit;

    private bool[SDLK_LAST]   keyMap;    
    private bool _3rdPerson;
    
    private ushort          middleX;
    private ushort          middleY;
    
    private vec2i mousecoords;
    private Tile selectedTile;
    private TilePos selectedTilePos;
    private vec3i selectedTileNormal;
    private bool tileSelected;
    
    private Tile copiedTile;

    
    this(Game g, GuiSystem s) {
        guiSystem = s;
        game = g;
        renderer = game.getRenderer();
        world = game.getWorld();
        camera = game.getCamera();
        scheduler = game.getScheduler();
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
        } else if (e.type == GuiEventType.MouseClick) {
            mouseClick(e);
        }
        return GuiEventResponse.Ignore;
    }
    
    override void activate(bool activated) {
        if (activated) {
            spawnGui();
        } else {
            iuGnwaps();
        }
    }
    
    void updateGui() {
        auto frameTime = renderer.getFrameTimeAverage();
        auto fps = 1_000_000 / frameTime;
        fpsText.setText(text(fps));
        frameTimeText.setText(text(frameTime));
        
        auto tickTime = scheduler.getTickTimeAverage();
        auto tps = 1_000_000 / tickTime;
        tickText.setText(text(tps));
        tickTimeText.setText(text(tickTime));
    }
    
    void spawnGui() {
        fpsText = new GuiElementText(guiSystem, vec2d(0, 0), "Fps counter");
        tickText = new GuiElementText(guiSystem, vec2d(0, fpsText.getRelativeRect.getBottom()), "Tick counter");
        
        frameTimeText = new GuiElementText(guiSystem, vec2d(0.2, 0), "Frame time counter");
        tickTimeText = new GuiElementText(guiSystem, vec2d(0.2, frameTimeText.getRelativeRect.getBottom()), "Tick time counter");
        
    }
    void iuGnwaps() {
        fpsText.destroy(); fpsText = null;
        tickText.destroy(); tickText = null;
        
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
    
    void mouseClick(GuiEvent e) {
        auto m = e.mouseClick;
        if (!m.down) {
            return;
        }
        else if (m.left && tileSelected) {
            copiedTile = selectedTile;
            //Remove transparensiness sometime!!
            enum airTile = Tile(TileTypeAir, cast(TileFlags)(TileFlags.transparent | TileFlags.valid), 0, 0);

            possesAI.changeTile(selectedTilePos, airTile);
        } else if (tileSelected) {
            TilePos whereToPlace = TilePos(selectedTilePos.value + selectedTileNormal);
            possesAI.changeTile(whereToPlace, copiedTile);
        }        
    }
    
    void tick(float dTime) {
        updatePossesed(dTime);
        rayPick();
        updateGui();
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
    
    
    
    int selectedTileBox; //TODO: Implement better way to render selected tile than debug functionality
    void rayPick(){
        vec3d start, dir;
        camera.getRayFromScreenCoords(mousecoords, start, dir);
        Tile tile;
        auto a = world.intersectTile(start, dir, 25, selectedTile, selectedTilePos, selectedTileNormal);;
        //writeln(a);
        tileSelected = 0.0 < a;
        if(tileSelected){
            if(selectedTileBox){
                removeAABB(selectedTileBox);
            }
            auto temp = TilePos(selectedTilePos.value); //Why? :S:S :P
            aabbd aabb = temp.getAABB();
            aabb.scale(vec3d(1.025f));
            selectedTileBox = addAABB(aabb);
        }
    }    
    
    
    
}



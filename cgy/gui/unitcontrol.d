

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
import gui.statistics;
import gui.inventorywindow;
import light;
import scheduler;
import settings;
import statistics;
import tiletypemanager;
import unit;
import util.intersect;
import util.rangefromto;
import util.util;
import world.world;



class HyperUnitControlInterfaceInputManager /*OF DOOM!!!*/ : GuiEventDump{ 
    
    private GuiSystem guiSystem;
    private GuiElementText fpsText, tickText, frameTimeText, tickTimeText, position, tileInfo;
    private StatisticsWindow statistics;
	private InventoryWindow inventoryWindow;

    private Game game;    
    private Renderer renderer;    //This and scheduler only used to get fps / tps info. Make proxy or thing?
    private Scheduler scheduler;
    private World world;
    private FPSControlAI possesAI;
    private Camera camera;
    private Unit* unit;

    private bool[SDLK_LAST]   keyMap;    
    private bool _3rdPerson;
    private bool freeFlight;
    private bool useMouse = true;
    
    private ushort          middleX;
    private ushort          middleY;
    
    private vec2i mousecoords;
    private Tile selectedTile;
    private TilePos selectedTilePos;
    private vec3i selectedTileNormal;
    private bool tileSelected;
    private double selectedDistance;
	
	private Entity selectedEntity;
    private bool entitySelected;
    
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
        copiedTile.type = TileTypeAir;

		inventoryWindow = new InventoryWindow(guiSystem, this, &possesAI.unit.inventory);
		guiSystem.addHotkey(SDLK_i, &(inventoryWindow.onOpenInventory));
    }
    
    private bool destroyed;
    ~this(){
        BREAK_IF(!destroyed);
    }    
    void destroy(){
        if( statistics !is null) {
            statistics.destroy();
        }
		if( inventoryWindow !is null) {
            inventoryWindow.destroy();
        }
        possesAI.destroy();
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
        possesAI = new FPSControlAI(world, renderer);
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
            onKey(k);
            return GuiEventResponse.Accept;
        } else if (e.type == GuiEventType.MouseClick) {
            mouseClick(e);
        }
        return GuiEventResponse.Ignore;
    }
    
    override void activate(bool activated) {
        if (activated) {
            spawnHUD();
        } else {
            DUHGnwaps();
        }
    }
    
    void updateHUD() {
        //We plus one microsecond to avoid division by 0.
        auto frameTime = g_Statistics.averageFPS()+1;
        auto fps = 1_000_000 / frameTime;
        fpsText.setText(text("fps ", fps));
        frameTimeText.setText(text("frametime ", frameTime));
        
        auto tickTime = g_Statistics.averageTPS()+1;
        auto tps = 1_000_000 / tickTime;
        tickText.setText(text("tps ", tps));
        tickTimeText.setText(text("ticktime ", tickTime));
        
        auto camPos = camera.getPosition();
        position.setText(text("position ", camPos.X, " ", camPos.Y, " ", camPos.Z));


        tileInfo.setText(text(selectedTile.describe(), "; ", selectedDistance));
    }
    
    void spawnHUD() {
        fpsText = new GuiElementText(guiSystem, vec2d(0, 0), "Fps counter");
        tickText = new GuiElementText(guiSystem, vec2d(0, fpsText.getRelativeRect.getBottom()), "Tick counter");
        
        frameTimeText = new GuiElementText(guiSystem, vec2d(0.2, 0), "Frame time counter");
        tickTimeText = new GuiElementText(guiSystem, vec2d(0.2, frameTimeText.getRelativeRect.getBottom()), "Tick time counter");
        
        position = new GuiElementText(guiSystem, vec2d(0, tickText.getRelativeRect.getBottom()), "Position");
        tileInfo = new GuiElementText(guiSystem, vec2d(0, position.getRelativeRect.getBottom()), "TileInfo");
        void spawnStatistics() {
            if( statistics is null) {
                statistics = new StatisticsWindow(guiSystem);
            }
        }
        guiSystem.addHotkey(SDLK_F1, &spawnStatistics);
    }
    void DUHGnwaps() {
        fpsText.destroy(); fpsText = null;        
        tickText.destroy(); tickText = null;
        frameTimeText.destroy(); frameTimeText = null;
        tickTimeText.destroy(); tickTimeText = null;        
        position.destroy(); position = null;
        tileInfo.destroy(); tileInfo = null;
        guiSystem.removeHotkey(SDLK_F1);
        if(statistics !is null) {
            statistics.destroy();
            statistics = null;
        }
    }
    
    void onKey(GuiEvent.KeyboardEvent k) {
        if (k.pressed) {
            if (k.SdlSym == SDLK_F3) {
                freeFlight = !freeFlight;
            }
            if (k.SdlSym == SDLK_F2) {
                useMouse = !useMouse;
            }
            if (k.SdlSym == SDLK_k) {
                mixin(Time!q{
                    writeln(cnt, "; ", usecs/1000);
                });
                int cnt=0;
                Tile tile;
                foreach(pos; RangeFromTo(vec3i(-SectorSize.x, -SectorSize.y, -SectorSize.z), vec3i(SectorSize.x, SectorSize.y, SectorSize.z))) {
                    tile = world.getTile(TilePos(pos));
                    cnt += cast(int)(!tile.isAir() && tile.valid);
                }
            }
            if (k.SdlSym == SDLK_l) {
                mixin(Time!q{
                    writeln(cnt, "; ", usecs/1000);
                });
                int cnt=0;
                foreach(pos; RangeFromTo(vec3i(-SectorSize.x, -SectorSize.y, -SectorSize.z), vec3i(SectorSize.x, SectorSize.y, SectorSize.z))) {
                    cnt += cast(int)world.isSolid(TilePos(pos));
                }
            }
        }
    }

    void mouseMove(GuiEvent e){
        auto m = e.mouseMove;
        auto x = m.pos.X;
        auto y = m.pos.Y;
        auto diffX = x - middleX;
        auto diffY = y - middleY;
        if((diffX != 0 || diffY != 0) && useMouse){
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
		else if (m.left && entitySelected) {
			if (selectedEntity.isDropped) {
				possesAI.unit.inventory.addToInventory(selectedEntity);
				world.getSector(selectedEntity.pos.getSectorNum()).removeEntity(selectedEntity);
			}
			else {
				selectedEntity.deconstruct();
			}
		}
        else if (m.left && tileSelected) {
            copiedTile = selectedTile;
            //Remove transparensiness sometime!!
            enum airTile = Tile(TileTypeAir, TileFlags.valid);

            possesAI.changeTile(selectedTilePos, airTile);
        } else if (m.right && tileSelected) {
            TilePos whereToPlace = TilePos(selectedTilePos.value + selectedTileNormal);
            auto pos = possesAI.getUnitPos();
            auto unitAABB = unit.aabb(&pos);
            auto tileAABB = whereToPlace.getAABB();
            if (! intersectsExclusive(unitAABB, tileAABB)) {
                possesAI.changeTile(whereToPlace, copiedTile);
            }
        } else if(m.middle && tileSelected) {
            vec3d pos = TilePos(selectedTilePos.value+selectedTileNormal).toEntityPos.value; // + 0.5 * convert!double(selectedTileNormal);
            LightSource light = new LightSource;
            light.position = pos;
            light.tint.set(0.8, 0.8, 0);
            light.strength = MaxLightStrength;
            possesAI.addLight(light);
        }

    }
    
    void tick(float dTime) {
        if (freeFlight ) {
            updateCamera();
        } else {
            updatePossesed(dTime);
        }
        hoverRay();
        updateHUD();
    }

    void updatePossesed(float dTime) { 
        double right = 0;
        double fwd = 0;
        //enum speed = 4.0;
        enum speed = 4.0;
        if(keyMap[SDLK_a]){ right-=speed; }
        if(keyMap[SDLK_d]){ right+=speed; }
        if(keyMap[SDLK_w]){ fwd+=speed; }
        if(keyMap[SDLK_s]){ fwd-=speed; }
        if(keyMap[SDLK_SPACE]){
            if(possesAI.onGround){
                //possesAI.fallSpeed = 4.5f;
                possesAI.fallSpeed = 14.5f;
            }
        }
        possesAI.move(right, fwd, 0.f, dTime);

        auto pos = possesAI.getUnitPos();
        auto dir = camera.getTargetDir();
        if(_3rdPerson) {
            pos -= util.util.convert!double(dir) * 7.5;
        } else {
            pos += vec3d(0, 0, 0.50); //Unit is 1.5 big now; unitpos is at 0.5 above feets
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
    void rayPickTile() {
        vec3d start, dir;
        camera.getRayFromScreenCoords(mousecoords, start, dir);
        Tile tile;
        auto a = world.intersectTile(start, dir, 25, selectedTile, selectedTilePos, selectedTileNormal, &selectedDistance);
        //writeln(a);
        tileSelected = a > 0;
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
	
	
	
	void rayPickEntity() {
		vec3d start, dir;
        camera.getRayFromScreenCoords(mousecoords, start, dir);
		double prevDist;
		entitySelected = false;
		foreach(entity ; world.getEntities()) {
			if (entity.aabb.intersectsWithLine(start, dir) &&
				(!entitySelected || prevDist > entity.pos.value.getDistanceFromSQ(camera.position))) {
					prevDist = entity.pos.value.getDistanceFromSQ(camera.position);
					selectedEntity = entity;
					entitySelected = true;
			}
		}
	}
	
	void hoverRay() {
		rayPickTile();
		rayPickEntity();
		if (entitySelected && 
			selectedEntity.pos.value.getDistanceFromSQ(camera.position) <
			selectedTilePos.toUnitPos().value.getDistanceFromSQ(camera.position)) { // fulhaxxs
				tileSelected = false;
			}
	}
    
    
    
}



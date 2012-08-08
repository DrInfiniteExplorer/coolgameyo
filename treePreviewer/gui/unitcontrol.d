

module gui.unitcontrol;

import std.conv;
import std.exception;
import std.math;
import std.stdio;

import derelict.sdl.sdl;

import ai.posessai;
import json;
import game;
import graphics.camera;
import graphics.debugging;
import graphics.ogl;
import graphics.renderer;
import graphics.raycastgpu;
import gui.all;
import gui.statistics;
import gui.inventorywindow;
import light;
import random.catmullrom;
import scheduler;
import settings;
import statistics;
import tiletypemanager;
import unit;
import util.intersect;
import util.rangefromto;
import util.util;
import world.world;
import entities.entity;
import entitytypemanager;



class HyperUnitControlInterfaceInputManager /*OF DOOM!!!*/ : GuiEventDump{ 
    
    private GuiSystem guiSystem;
    private GuiElementText fpsText, tickText, frameTimeText, tickTimeText, position, tileInfo, timeInfo, renderMethodInfo, currentTypeGuiText;
    private StatisticsWindow statistics;
	private InventoryWindow inventoryWindow;

    private Game game;    
    private Renderer renderer;    //This and scheduler only used to get fps / tps info. Make proxy or thing?
    private Scheduler scheduler;
    private World world;
    private FPSControlAI possesAI;
    private Camera camera;
    private Unit unit;

    private bool[SDLK_LAST]   keyMap;    
    private bool _3rdPerson;
    private bool freeFlight;
    private bool useMouse = true;
    private bool turbo = false;
    
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

    struct CamDemoPoints {
        vec3d[] camPos;
        vec3d[] camTargetDir;
    };

    private CamDemoPoints camDemoPoints;
    private bool runCamDemo=false;
    private float camDemoTime = 0.0f;
    private int camDemoLine;
    
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

        Value jsonRoot;
        if(loadJSONFile("saves/camdemo.json", &jsonRoot)) {
            json.read(camDemoPoints, jsonRoot);
        }
        do {
            currentTypeId++;
            if (currentTypeId >= world.entityTypeManager.types.length) currentTypeId = 0;
        } while (world.entityTypeManager.types[currentTypeId].treelike.woodMaterial == "");
        game.treeManager.setCurrentType(world.entityTypeManager.types[currentTypeId]);
    }
    
    private bool destroyed;
    ~this(){
        BREAK_IF(!destroyed);
    }    
    void destroy(){

        auto jsonRoot = encode(camDemoPoints);
        std.file.write("saves/camdemo.json", prettifyJSON(jsonRoot));

        if( statistics !is null) {
            statistics.destroy();
        }
		if( inventoryWindow !is null) {
            inventoryWindow.destroy();
        }
        possesAI.destroy();
        destroyed = true;
    }
    
    void setControlledUnit(Unit u) {
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

    enum renderMethods=[
        "A*(M+R)",
        "A*M",
        "A*R",
        "A",
        "M",
        "R"
    ];
    
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
        timeInfo.setText(world.getDayTimeString());

        renderMethodInfo.setText(renderMethods[renderSettings.renderTrueWorld]);
        currentTypeGuiText.setText(world.entityTypeManager.byID(currentTypeId).name);
    }
    
    void spawnHUD() {
        fpsText = new GuiElementText(guiSystem, vec2d(0, 0), "Fps counter", false);
        tickText = new GuiElementText(guiSystem, vec2d(0, fpsText.getRelativeRect.getBottom()), "Tick counter", false);
        
        frameTimeText = new GuiElementText(guiSystem, vec2d(0.2, 0), "Frame time counter", false);
        tickTimeText = new GuiElementText(guiSystem, vec2d(0.2, frameTimeText.getRelativeRect.getBottom()), "Tick time counter", false);

        renderMethodInfo = new GuiElementText(guiSystem, vec2d(0.4, 0), "Render method", false);
        
        position = new GuiElementText(guiSystem, vec2d(0, tickText.getRelativeRect.getBottom()), "Position", false);
        tileInfo = new GuiElementText(guiSystem, vec2d(0, position.getRelativeRect.getBottom()), "TileInfo", false);
        timeInfo = new GuiElementText(guiSystem, vec2d(0, tileInfo.getRelativeRect.getBottom()), "00:00", false);

        currentTypeGuiText = new GuiElementText(guiSystem, vec2d(0, timeInfo.getRelativeRect.getBottom()), "OMGLOLWTFBBQ", false);
        void spawnStatistics() {
            if( statistics is null) {
                statistics = new StatisticsWindow(guiSystem);
            }
        }
        //guiSystem.addHotkey(SDLK_F1, &spawnStatistics);
    }
    void DUHGnwaps() {
        fpsText.destroy(); fpsText = null;        
        tickText.destroy(); tickText = null;
        frameTimeText.destroy(); frameTimeText = null;
        tickTimeText.destroy(); tickTimeText = null;        
        position.destroy(); position = null;
        tileInfo.destroy(); tileInfo = null;
        timeInfo.destroy(); timeInfo = null;
        renderMethodInfo.destroy(); renderMethodInfo = null;
        currentTypeGuiText.destroy(); currentTypeGuiText = null;
        //guiSystem.removeHotkey(SDLK_F1);
        if(statistics !is null) {
            statistics.destroy();
            statistics = null;
        }
    }
    
    void onKey(GuiEvent.KeyboardEvent k) {
        if (k.SdlSym == SDLK_LSHIFT) {
            turbo = k.pressed;
        }
        if (k.pressed) {
            if (k.SdlSym == SDLK_F2) {
                useMouse = !useMouse;
            }
            if (k.SdlSym == SDLK_F3) {
                freeFlight = !freeFlight;
            }

            if (k.SdlSym == SDLK_F6) {
                renderSettings.renderTrueWorld--;
                if(renderSettings.renderTrueWorld < 0) {
                    renderSettings.renderTrueWorld = 5;
                }
            }
            if (k.SdlSym == SDLK_F7) {
                renderSettings.renderTrueWorld = (renderSettings.renderTrueWorld+1)%6;
            }
            if (k.SdlSym == SDLK_F8) {
                reloadOpenCl();
            }
            if (k.SdlSym == SDLK_p) {
                game.treeManager.toggleDrawTiles();
            }
            if (k.SdlSym == SDLK_o) {
                game.treeManager.toggleDrawLeafs();
            }
            if (k.SdlSym == SDLK_l) {
                game.treeManager.toggleDrawDebugLines();
            }

            if (k.ch >= '0' && k.ch <= '9') {
                game.treeManager.toggleDrawBranchId(to!(int)(k.ch)-48);
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
            if(!runCamDemo) {
                camera.mouseMove( diffX,  diffY);
            }
        }
        mousecoords.set(x, y);
    }    
    
    ushort currentTypeId = 0;
    void mouseClick(GuiEvent e) {
        auto m = e.mouseClick;
        if (!m.down) {
            return;
        }
        else if (m.left && tileSelected) {
            TilePos whereToPlace = TilePos(selectedTilePos.value + selectedTileNormal);
            game.treeManager.plantTree(whereToPlace, game.treeManager.currentType);

            //copiedTile = selectedTile;
            //Remove transparensiness sometime!!
            //enum airTile = Tile(TileTypeAir, TileFlags.valid);
            //possesAI.changeTile(selectedTilePos, airTile);
        } else if (m.right) {
            game.treeManager.growTrees();
            //TilePos whereToPlace = TilePos(selectedTilePos.value + selectedTileNormal);
            //auto pos = possesAI.getUnitPos();
            //auto unitAABB = unit.aabb(&pos);
            //auto tileAABB = whereToPlace.getAABB();
            //if (! intersectsExclusive(unitAABB, tileAABB)) {
            //    possesAI.changeTile(whereToPlace, copiedTile);
            //}
        } else if(m.middle/* && tileSelected*/) {
            do {
                currentTypeId++;
                if (currentTypeId >= world.entityTypeManager.types.length) currentTypeId = 0;
            } while (world.entityTypeManager.types[currentTypeId].treelike.woodMaterial == "");
            game.treeManager.setCurrentType(world.entityTypeManager.types[currentTypeId]);

            //auto o = newEntity();
            //o.pos = TilePos(selectedTilePos.value+selectedTileNormal).toEntityPos;
            //o.type = world.entityTypeManager.byName("torch");
            //world.addEntity(o);
        }

    }
    
    void tick(float dTime) {
        if (freeFlight ) {
            updateCamera(dTime);
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
        double speed = 4.0;
        if(turbo) speed = 30.0;
        if(keyMap[SDLK_a]){ right-=speed; }
        if(keyMap[SDLK_d]){ right+=speed; }
        if(keyMap[SDLK_w]){ fwd+=speed; }
        if(keyMap[SDLK_s]){ fwd-=speed; }
        if(keyMap[SDLK_SPACE]){
            if(possesAI.onGround){
                possesAI.fallSpeed = 4.6666f;
                if(turbo) possesAI.fallSpeed = 40.6666f;
                //possesAI.fallSpeed = 5.0f;
            }
        }
        possesAI.move(right, fwd, 0.0f, dTime);

        auto pos = possesAI.getUnitPos();
        auto dir = camera.getTargetDir();
        if(_3rdPerson) {
            pos -= dir.convert!double() * 7.5;
        } else {
            pos += vec3d(0, 0, 0.50); //Unit is 1.5 big now; unitpos is at 0.5 above feets
        }
        camera.setPosition(pos);
        auto rad = atan2(dir.Y, dir.X);
        possesAI.setRotation(rad);
    }
    
    //Call to update free-flying camera
    void updateCamera(double dTime) {
        double speed = 10.0;
        if(turbo) speed = 50;
        speed *= dTime;
        if(keyMap[SDLK_a]){ camera.axisMove(-speed, 0.0, 0.0); }
        if(keyMap[SDLK_d]){ camera.axisMove( speed, 0.0, 0.0); }
        if(keyMap[SDLK_w]){ camera.axisMove( 0.0, speed, 0.0); }
        if(keyMap[SDLK_s]){ camera.axisMove( 0.0,-speed, 0.0); }
        if(keyMap[SDLK_SPACE]){ camera.axisMove( 0.0, 0.0, speed); }
        if(keyMap[SDLK_LCTRL]){ camera.axisMove( 0.0, 0.0,-speed); }
    }
    
    
    
    int selectedTileBox; //TODO: Implement better way to render selected tile than debug functionality
    void rayPickTile() {
        vec3d start, dir;
        camera.getRayFromScreenCoords(mousecoords, start, dir);
        Tile tile;
        auto a = world.intersectTile(start, dir, 200, selectedTile, selectedTilePos, selectedTileNormal, &selectedDistance);
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
		double prevDist, dist;
		entitySelected = false;
		foreach(entity ; world.getEntities()) {
            dist = entity.pos.value.getDistanceFromSQ(camera.position);
			if (entity.aabb.intersectsWithLine(start, dir) && dist>0.5f &&
                dir.dotProduct(entity.pos.value-camera.position) > 0 &&
				(!entitySelected || prevDist > dist)) {
					prevDist = dist;
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
        else {
            entitySelected = false;
        }
	}
    
    
    
}



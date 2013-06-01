

module gui.unitcontrol;

import std.conv;
import std.exception;
import std.math;
import std.stdio;

import derelict.sdl.sdl;

import ai.possessai;
import json;
import gaia;
import game;
import graphics.camera;
import graphics.debugging;
import graphics.ogl;
import graphics.renderer;
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
//import util.gc;
import util.strings;
import util.rangefromto;
import util.util;
import worldstate.worldstate;
import entities.entity;
import entitytypemanager;



class HyperUnitControlInterfaceInputManager /*OF DOOM!!!*/ : GuiEventDump{ 

    private GuiSystem guiSystem;
    private GuiElementText fpsText, tickText, frameTimeText, tickTimeText, position, tileInfo, timeInfo, renderMethodInfo;
    private StatisticsWindow statistics;
    private InventoryWindow inventoryWindow;

    private Game game;    
    private Renderer renderer;    //This and scheduler only used to get fps / tps info. Make proxy or thing?
    private WorldState world;
    private FPSControlAI possesAI;
    private Camera camera;
    private Unit unit;

    private bool[SDLK_LAST]   keyMap;    
    private bool _3rdPerson;
    private bool freeFlight;
    private bool useMouse = true;
    private bool turbo = false;
    private bool turboTurbo = false;

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
        setControlledUnit(game.getActiveUnit());

        middleX = cast(ushort)renderSettings.windowWidth/2;
        middleY = cast(ushort)renderSettings.windowHeight/2;
        copiedTile.type = TileTypeAir;

        inventoryWindow = new InventoryWindow(guiSystem, this, &possesAI.unit.inventory);
        guiSystem.addHotkey(SDLK_i, &(inventoryWindow.onOpenInventory));

        Value jsonRoot;
        if(loadJSON("saves/camdemo.json", jsonRoot)) {
            jsonRoot.read(camDemoPoints);
        }
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
            //enforce(possesAI is ai, "Controlled / possessed unit has wrong ai! :S");
            possesAI.destroy();
        }
        unit = u;
        possesAI = new FPSControlAI(unit, world , world.sceneManager);
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

    static immutable renderMethods=[
        "A*(M+R)",
        "A*M",
        "A*R",
        "A",
        "M",
        "R"
            ];




    long oldFrameTime;
    long oldTickTime;
    vec3d oldCamPos;
    Tile oldTile;
    float oldDistance;
    int oldRenderMethod;
    StringBuilder fpsString;
    StringBuilder frameTimeString;
    StringBuilder tpsString;
    StringBuilder tickTimeString;
    StringBuilder positionString;
    StringBuilder tileString;
    StringBuilder renderString;
    void updateHUD() {

        //We plus one microsecond to avoid division by 0.
        auto frameTime = g_Statistics.averageFPS()+1;
        auto fps = 1_000_000 / frameTime;
        if(frameTime != oldFrameTime) {
            fpsText.setText(fpsString("fps %d", fps));
            frameTimeText.setText(frameTimeString("frametime %d", frameTime));
            oldFrameTime = frameTime;
        }

        auto tickTime = g_Statistics.averageTPS()+1;
        auto tps = 1_000_000 / tickTime;
        if(tickTime != oldTickTime) {
            tickText.setText(tpsString("tps %d", tps));
            tickTimeText.setText(tickTimeString("ticktime %d", tickTime));
            oldTickTime = tickTime;
        }

        auto camPos = camera.getPosition();
        if(camPos != oldCamPos) {
            position.setText(positionString("position %f, %f, %f", camPos.x, camPos.y, camPos.z));
            oldCamPos = camPos;
        }

        if(oldTile != selectedTile && oldDistance != selectedDistance) {
            tileInfo.setText(tileString("%s; %f", selectedTile.describe(), selectedDistance));
            oldTile = selectedTile;
            oldDistance = selectedDistance;
        }

        if(oldRenderMethod != renderSettings.renderTrueWorld) {
            renderMethodInfo.setText(renderMethods[renderSettings.renderTrueWorld]);
            oldRenderMethod = renderSettings.renderTrueWorld;
        }

        //timeInfo.setText(world.getDayTimeString());

        updateDemoPath();
    }

    void spawnHUD() {
        fpsText = new GuiElementText(guiSystem, vec2d(0, 0), "Fps counter", false);
        tickText = new GuiElementText(guiSystem, vec2d(0, fpsText.bottomOf), "Tick counter", false);

        frameTimeText = new GuiElementText(guiSystem, vec2d(0.2, 0), "Frame time counter", false);
        tickTimeText = new GuiElementText(guiSystem, vec2d(0.2, frameTimeText.bottomOf), "Tick time counter", false);

        renderMethodInfo = new GuiElementText(guiSystem, vec2d(0.4, 0), "Render method", false);

        position = new GuiElementText(guiSystem, vec2d(0, tickText.bottomOf), "Position", false);
        tileInfo = new GuiElementText(guiSystem, vec2d(0, position.bottomOf), "TileInfo", false);
        timeInfo = new GuiElementText(guiSystem, vec2d(0, tileInfo.bottomOf), "00:00", false);
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
        timeInfo.destroy(); timeInfo = null;
        renderMethodInfo.destroy(); renderMethodInfo = null;
        guiSystem.removeHotkey(SDLK_F1);
        if(statistics !is null) {
            statistics.destroy();
            statistics = null;
        }
    }

    void onKey(GuiEvent.KeyboardEvent k) {
        if (k.SdlSym == SDLK_LSHIFT) {
            turbo = k.pressed;
        }
        if (k.SdlSym == SDLK_RSHIFT) {
            turboTurbo = k.pressed;
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
            if (k.SdlSym == SDLK_F9) {
                if(camDemoPoints.camPos.length < 4) {
                    camDemoPoints.camPos ~= camera.getPosition();
                    camDemoPoints.camTargetDir ~= camera.getTargetDir();
                    camDemoPoints.camPos ~= camera.getPosition();
                    camDemoPoints.camTargetDir ~= camera.getTargetDir();
                } else {
                    camDemoPoints.camPos[$-1] = camera.getPosition();
                    camDemoPoints.camTargetDir[$-1] = camera.getTargetDir();
                    camDemoPoints.camPos ~= camera.getPosition();
                    camDemoPoints.camTargetDir ~= camera.getTargetDir();
                }
                updateDemoPath();
            }
            if (k.SdlSym == SDLK_F10) {
                if(camDemoPoints.camPos.length < 4) {
                    return;
                }
                runCamDemo = true;
                camDemoTime = 0;
            }
            if (k.SdlSym == SDLK_F11) {
                if (camDemoPoints.camPos.length == 4) {
                    camDemoPoints.camPos.length -= 2;
                    camDemoPoints.camTargetDir.length -= 2;
                }
                else if (camDemoPoints.camPos.length > 2) {
                    camDemoPoints.camPos.length -= 1;
                    camDemoPoints.camTargetDir.length -= 1;
                    camDemoPoints.camPos[$-1] = camDemoPoints.camPos[$-2];
                    camDemoPoints.camTargetDir[$-1] = camDemoPoints.camTargetDir[$-2];
                }
                else {
                    camDemoPoints.camPos.length = 0;
                    camDemoPoints.camTargetDir.length = 0;
                }
            }
            if (k.SdlSym == SDLK_k) {
                camera.setPosition(camera.getPosition() + vec3d(0.0, 0.0, 1000.0));
            }
            if (k.SdlSym == SDLK_p) {
                    EntityPos topOfTheWorld2(TileXYPos xy) {
                    auto top = world.getTopTilePos(xy);
                    msg("top: ", top);
                    auto ret = top.toEntityPos();
                    ret.value.z += 1;
                    msg("ret: ", ret);

                    return ret;
                }
                Tile tile = Tile(world.tileTypeManager.byName("birchtree"), TileFlags.valid);
                auto tilePos = topOfTheWorld2(TileXYPos(vec2i(3,2)));
                world.unsafeSetTile(tilePos, tile);
                tile = Tile(world.tileTypeManager.byName("birchleaf"), TileFlags.valid);
                tilePos = topOfTheWorld2(TileXYPos(vec2i(3,3)));
                world.unsafeSetTile(tilePos, tile);
                tile = Tile(world.tileTypeManager.byName("smoothstone"), TileFlags.valid);
                tilePos = topOfTheWorld2(TileXYPos(vec2i(3,4)));
                world.unsafeSetTile(tilePos, tile);
            }

        }
    }

    void updateCamDemo(float dTime) {
        vec3d camPos = CatmullRomSpline(camDemoTime, camDemoPoints.camPos);
        vec3d camTargetDir = CatmullRomSpline(camDemoTime, camDemoPoints.camTargetDir);
        camDemoTime += dTime * 0.4f / cast(float)camDemoPoints.camPos.length;

        camera.setPosition(camPos);
        camera.setTargetDir(camTargetDir);

        if(camDemoTime > 1.0f) {
            runCamDemo = false;
        }
    }

    void updateDemoPath() {
        /* commented out because dont want to get statement is not reachable-warning
           return;
           float time;
           int len = camDemoPoints.camPos.length*4;
           if(len < 16) {
           return;
           }
           vec3d[] camPoses;
           foreach(idx ; 0 .. len) {
           time = cast(float)idx / cast(float)len;
           auto pos = CatmullRomSpline(time, camDemoPoints.camPos);
           auto dir = CatmullRomSpline(time, camDemoPoints.camTargetDir);
           camPoses ~= pos;
           camPoses ~= pos+dir;
           camPoses ~= pos;
           }
           removeLine(camDemoLine);
           camDemoLine = addLine(camPoses, vec3f(1.0, 0.0, 0.0));
         */
    }

    void mouseMove(GuiEvent e){
        auto m = e.mouseMove;
        auto x = m.pos.x;
        auto y = m.pos.y;
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

    void mouseClick(GuiEvent e) {
        auto m = e.mouseClick;
        if (!m.down) {
            return;
        } else if (m.left && entitySelected) {
            if (selectedEntity.isDropped) {
                // BUG: SÅHÄR GÖR MAN INTE
                // använd changes!
                possesAI.unit.inventory.addToInventory(selectedEntity);
                world.removeEntity(selectedEntity);
            } else {
                selectedEntity.deconstruct();
            }
        } else if (m.left && tileSelected) {
            copiedTile = selectedTile;
            //Remove transparensiness sometime!!

            //possesAI.changeTile(selectedTilePos, airTile);
        } else if (m.right && tileSelected) {
            TilePos whereToPlace = TilePos(selectedTilePos.value + selectedTileNormal);
            auto pos = possesAI.getUnitPos();
            auto unitAABB = unit.aabb(&pos);
            auto tileAABB = whereToPlace.getAABB();
            if (! intersectsExclusive(unitAABB, tileAABB)) {
                //possesAI.changeTile(whereToPlace, copiedTile);
            }
        } else if (m.middle && tileSelected) {
            //vec3d pos = TilePos(selectedTilePos.value+selectedTileNormal).toEntityPos.value; // + 0.5 * selectedTileNormal.convert!double();

            //auto entityTypeId = world._worldProxy.entityTypeManager.byName("torch").id;
            auto entityTypeId = world._worldProxy.entityTypeManager.byName("tree01").id;
            auto pos = TilePos(selectedTilePos.value+selectedTileNormal).toEntityPos;
            auto entityId = INVALID_ENTITY_ID;
            auto clanId = 0; // Gaia
            world._worldProxy.createEntity(entityId, entityTypeId, clanId, pos);
        }

    }

    void tick(float dTime) {
        import util.memory;


        //mixin(MemDiff!("hyper.tick"));
        if(runCamDemo) {
            updateCamDemo(dTime);
            updateHUD();
            return;
        }
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
        //immutable speed = 4.0;
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
        auto rad = atan2(dir.y, dir.x);
        possesAI.setRotation(rad);
    }

    //Call to update free-flying camera
    void updateCamera(double dTime) {
        double speed = 10.0;
        if(turbo) speed = 120;
        if(turboTurbo) speed = 10_000;
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
        return;
        /*

        Commented out now because getEntities spawns memory on the heap every frame.

        vec3d start, dir;
        camera.getRayFromScreenCoords(mousecoords, start, dir);
        double prevDist, dist;
        entitySelected = false;
        foreach(entity ; world.getEntities()) {
            dist = entity.entityData.pos.value.getDistanceSQ(camera.position);
            if (entity.aabb.intersectsWithLine(start, dir) && dist>0.5f &&
                    dir.dotProduct(entity.pos.value-camera.position) > 0 &&
                    (!entitySelected || prevDist > dist)) {
                prevDist = dist;
                selectedEntity = entity;
                entitySelected = true;
            }
        }
        */
    }

    void hoverRay() {
        rayPickTile();
        rayPickEntity();
        if (entitySelected && 
                selectedEntity.pos.value.getDistanceSQ(camera.position) <
                selectedTilePos.toUnitPos().value.getDistanceSQ(camera.position)) { // fulhaxxs
            tileSelected = false;
        }
        else {
            entitySelected = false;
        }
    }



}



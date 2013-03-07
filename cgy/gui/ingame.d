module gui.ingame;


import derelict.sdl.sdl;

import ai.possessai;
import game;
import graphics.camera;
import gui.all;
import settings;
import unit;
import util.util;
import worldstate.worldstate;

class InGameGui : public GuiElement{

    Game game;
    GuiSystem guiSystem;
    Unit playerUnit;
    FpsHandler fpsHandler;

    this(GuiSystem parent, Game _game) {
        super(parent);
        guiSystem = parent;
        game = _game;
    }

    override void destroy() {
        if(fpsHandler) {
            fpsHandler.destroy();
        }
        super.destroy();
    }


    override void tick(float dTime) {
        auto activeUnit = game.getActiveUnit();
        if(playerUnit !is activeUnit) {
            playerUnit = activeUnit;
            fpsHandler = new FpsHandler(this, game);
            guiSystem.setEventDump(fpsHandler);
        }
    }


}

class FpsHandler : GuiEventDump {
    Game game;
    WorldState world;
    InGameGui gui;
    FPSControlAI possessAI;

    bool[SDLK_LAST]   keyMap;

    vec2i mousecoords;
    ushort middleX, middleY;
    bool useMouse = true;

    Camera camera;
    bool freeFlight;

    this(InGameGui _gui, Game _game) {
        gui = _gui;
        game = _game;
        world = game.getWorld;
        camera = game.getCamera;

        possessAI = new FPSControlAI(game.getActiveUnit, world, game.getSceneManager);
        game.setActiveUnitPos(UnitPos(possessAI.unitPos));

        middleX = cast(ushort)renderSettings.windowWidth / 2;
        middleY = cast(ushort)renderSettings.windowHeight / 2;
    }

    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {
        if(possessAI) {
            possessAI.destroy();
        }
        destroyed = true;
    }


    void mouseMove(GuiEvent e){
        auto m = e.mouseMove;
        auto x = m.pos.x;
        auto y = m.pos.y;
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
        } else if (m.left) {
            msg("Add damage to tile under cursor, like.");
            rayPickTile();
            if(selectedTileIterations > 0) {
                game.damageTile(selectedTilePos, 5);
            }
        } else if (m.right) {

        } else if (m.middle) {
        }
    }
    void onKey(GuiEvent.KeyboardEvent k) {
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

            if (k.SdlSym == SDLK_t) { // TELEPORT WOOOH
                if(!freeFlight) return;
                possessAI.unitPos = camera.getPosition;
                game.setActiveUnitPos(UnitPos(possessAI.unitPos));
                freeFlight = false;
            }
            if (k.SdlSym == SDLK_k) {
                camera.setPosition(camera.getPosition() + vec3d(0.0, 0.0, 1000.0));
            }
        }
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
    }

    override void tick(float dTime) {
        if (freeFlight ) {
            updateCamera(dTime);
        } else {
            updatePossesed(dTime);
        }
        //hoverRay();
    }

    void updatePossesed(float dTime) { 
        double right = 0;
        double fwd = 0;
        double speed = 4.0;

        if(keyMap[SDLK_a]){ right-=speed; }
        if(keyMap[SDLK_d]){ right+=speed; }
        if(keyMap[SDLK_w]){ fwd+=speed; }
        if(keyMap[SDLK_s]){ fwd-=speed; }
        if(keyMap[SDLK_SPACE]){
            if(possessAI.onGround){
                possessAI.fallSpeed = 4.6666f;
            }
        }
        possessAI.move(right, fwd, 0.0f, dTime);

        auto pos = possessAI.getUnitPos();
        auto dir = camera.getTargetDir();
        pos += vec3d(0, 0, 0.50); //Unit is 1.5 big now; unitpos is at 0.5 above feets
        camera.setPosition(pos);
        import std.math : atan2;
        auto rad = atan2(dir.y, dir.x);
        possessAI.setRotation(rad);
        game.setActiveUnitPos(UnitPos(possessAI.unitPos));
    }

    //Call to update free-flying camera
    void updateCamera(double dTime) {
        double speed = 10.0;
        speed *= dTime;
        if(keyMap[SDLK_LSHIFT]) speed *= 30;
        if(keyMap[SDLK_a]){ camera.axisMove(-speed, 0.0, 0.0); }
        if(keyMap[SDLK_d]){ camera.axisMove( speed, 0.0, 0.0); }
        if(keyMap[SDLK_w]){ camera.axisMove( 0.0, speed, 0.0); }
        if(keyMap[SDLK_s]){ camera.axisMove( 0.0,-speed, 0.0); }
        if(keyMap[SDLK_SPACE]){ camera.axisMove( 0.0, 0.0, speed); }
        if(keyMap[SDLK_LCTRL]){ camera.axisMove( 0.0, 0.0,-speed); }
    }



    Tile selectedTile;
    TilePos selectedTilePos;
    vec3i selectedTileNormal;
    double selectedTileDistance;
    int selectedTileIterations; // if > 0 then valid pick
    void rayPickTile() {
        vec3d start, dir;
        camera.getRayFromScreenCoords(mousecoords, start, dir);
        selectedTileIterations = world.intersectTile(start, dir, 25, selectedTile, selectedTilePos, selectedTileNormal, &selectedTileDistance);
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
        /*
        if (entitySelected && 
            selectedEntity.pos.value.getDistanceSQ(camera.position) <
            selectedTilePos.toUnitPos().value.getDistanceSQ(camera.position)) { // fulhaxxs
                tileSelected = false;
            }
        else {
            entitySelected = false;
        }
        */
    }



}

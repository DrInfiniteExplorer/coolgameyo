module gui.ingame_third;

import derelict.sdl.sdl;

import ai.possessai;
import game;
import graphics.camera;
import gui.all;
import gui.debuginfo;
import settings;
import unit;
import util.util;
import worldstate.worldstate;

import gui.ingame;

class PlanningMode : GuiEventDump {
    Game game;
    WorldState world;
    InGameGui gui;

    bool[SDLK_LAST]   keyMap;

    vec2i mousecoords;
    ushort middleX, middleY;
    bool useMouse = true;

    Camera camera;

    double focusZ;
    vec2d focusXY;

    bool rotateCamera = false;

    this(InGameGui _gui, Game _game) {
        gui = _gui;
        game = _game;
        world = game.getWorld;
        camera = game.getCamera;

        middleX = cast(ushort)renderSettings.windowWidth / 2;
        middleY = cast(ushort)renderSettings.windowHeight / 2;
    }

    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {
        destroyed = true;
    }


    void mouseMove(GuiEvent e){
        auto m = e.mouseMove;
        auto x = m.pos.x;
        auto y = m.pos.y;
        auto diffX = x - middleX;
        auto diffY = y - middleY;
        /*
        if((diffX != 0 || diffY != 0) && useMouse){
            SDL_WarpMouse(middleX, middleY);
            camera.mouseMove( diffX,  diffY);
        }
        */

        if(rotateCamera) {
            diffX = x - mousecoords.x;
            diffY = y - mousecoords.y;
            camera.rotateAround(10.0f, diffX, diffY);
            SDL_WarpMouse(cast(ushort)mousecoords.x, cast(ushort)mousecoords.y);
        } else {
            mousecoords.set(x, y);
        }
    }    

    void hideMouse(bool hide) {
    }

    void mouseClick(GuiEvent e) {
        auto m = e.mouseClick;
        if (m.right) {
            rotateCamera = m.down;
            hideMouse(m.down);
            return;
        }
        if (!m.down) {
            return;
        } else if (m.left) {
            msg("Add damage to tile under cursor, like.");
            rayPickTile();
            if(selectedTileIterations > 0) {
                game.damageTile(selectedTilePos, 5);
            }
        } else if (m.middle) {
            vec3d start, dir;
            camera.getRayFromScreenCoords(mousecoords, start, dir);
            Tile tile;

            import util.tileiterator;
            foreach(tilePos ; TileIterator(start, dir, 25, null)) {
                game.damageTile(tilePos, 5);
            }

        }
    }
    void onKey(GuiEvent.KeyboardEvent k) {
        if (k.pressed) {
            if (k.SdlSym == SDLK_F2) {
                useMouse = !useMouse;
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
        updateCamera(dTime);
    }

    //Call to update free-flying camera
    void updateCamera(double dTime) {
        /*
        double speed = 10.0;
        speed *= dTime;
        if(keyMap[SDLK_LSHIFT]) speed *= 30;
        if(keyMap[SDLK_a]){ camera.axisMove(-speed, 0.0, 0.0); }
        if(keyMap[SDLK_d]){ camera.axisMove( speed, 0.0, 0.0); }
        if(keyMap[SDLK_w]){ camera.axisMove( 0.0, speed, 0.0); }
        if(keyMap[SDLK_s]){ camera.axisMove( 0.0,-speed, 0.0); }
        if(keyMap[SDLK_SPACE]){ camera.axisMove( 0.0, 0.0, speed); }
        if(keyMap[SDLK_LCTRL]){ camera.axisMove( 0.0, 0.0,-speed); }
        */
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

    }

    void hoverRay() {
        rayPickTile();
        rayPickEntity();
    }
}

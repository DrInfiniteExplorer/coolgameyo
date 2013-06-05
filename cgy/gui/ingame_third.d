module gui.ingame_third;

import std.math : floor;

import derelict.sdl.sdl;

import ai.possessai;
import game: game;
import graphics.camera;
import gui.all;
import gui.debuginfo;
import math.math;
import settings;
import unit;
import util.util;
import worldstate.worldstate;

import gui.ingame;

class PlanningMode : GuiEventDump {
    WorldState world;
    InGameGui gui;

    bool[SDLK_LAST]   keyMap;

    vec2i mouseCoords;
    ushort middleX, middleY;
    bool useMouse = true;

    Camera camera;

    double focusZ;
    float focusDistance = 10.0;
    float desiredFocusDistance = 10.0;
    vec2d focusXY;

    bool rotateCamera = false;

    this(InGameGui _gui) {
        gui = _gui;
        world = game.getWorld;
        camera = game.getCamera;
        focusZ = camera.position.z;

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
            diffX = x - mouseCoords.x;
            diffY = y - mouseCoords.y;
            camera.rotateAround(focusDistance, diffX, diffY);
            SDL_WarpMouse(cast(ushort)mouseCoords.x, cast(ushort)mouseCoords.y);
        } else {
            mouseCoords.set(x, y);
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
        if( (m.wheelUp || m.wheelDown) && m.down) {
            if(keyMap[SDLK_LCTRL]) {
                int dir = m.wheelUp ? 1 : -1;
                focusZ += dir;
            } else {
                auto mod = m.wheelUp ? 0.9 : 1.1;
                desiredFocusDistance = clamp(desiredFocusDistance * mod, 1.0, 25.0);
            }
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
            camera.getRayFromScreenCoords(mouseCoords, start, dir);
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
        if(activated) {
            focusDistance = 1.0;
            focusZ = floor(camera.position.z);
            camera.position -= camera.targetDir * focusDistance;
        }
    }

    override void tick(float dTime) {
        updateCamera(dTime);
    }

    //Call to update free-flying camera
    void updateCamera(double dTime) {
        static immutable scrollRegion = 16;
        static immutable scrollSpeed = 10.0f;

        float moveX = 0.0f;
        float moveY = 0.0f;
        if(mouseCoords.x < scrollRegion ||
            keyMap[SDLK_LEFT]) {
            moveX = -1.0;
        } else if(mouseCoords.x >= renderSettings.windowWidth - scrollRegion ||
            keyMap[SDLK_RIGHT]) {
            moveX =  1.0f;
        }
        if(mouseCoords.y < scrollRegion ||
            keyMap[SDLK_UP]) {
            moveY = 1.0;
        } else if(mouseCoords.y >= renderSettings.windowHeight - scrollRegion ||
            keyMap[SDLK_DOWN]) {
            moveY = -1.0f;
        }
        moveX *= dTime * scrollSpeed;
        moveY *= dTime * scrollSpeed;

        auto fwd = camera.getTargetDir();
        fwd.z = 0;
        fwd.normalizeThis();
        auto right = vec3d(fwd.y, -fwd.x, 0);

        auto x = (fwd * moveY + right * moveX).x;
        auto y = (fwd * moveY + right * moveX).y;
        camera.absoluteAxisMove(x, y, 0);

        double camFocusZ = camera.position.z + camera.targetDir.z * focusDistance;

        if(camFocusZ != focusZ) {
            auto deltaZ = dTime * 5.0 * (focusZ - camFocusZ);
            camera.position.z += deltaZ;
        }
        if(desiredFocusDistance != focusDistance) {
            auto deltaFocus = dTime * 5.0 * (desiredFocusDistance - focusDistance);
            camera.relativeAxisMove(0, -deltaFocus, 0);
            focusDistance +=deltaFocus;
        }

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
        camera.getRayFromScreenCoords(mouseCoords, start, dir);
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

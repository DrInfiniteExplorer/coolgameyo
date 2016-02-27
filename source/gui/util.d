
module gui.util;

import derelict.sdl2.sdl;

import graphics.camera;
import gui.all;
import cgy.math.vector;
import settings;
import cgy.debug_.debug_: BREAK_IF;




class FreeFlightCamera : GuiEventDump {
    bool[int]   keyMap;

    bool keyPressed(int key)
    {
        return key in keyMap && keyMap[key];
    }

    vec2i mousecoords;
    ushort middleX, middleY;
    bool useMouse = true;

    Camera camera;

    this(Camera _camera) {
        camera = _camera;
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

    void mouseMove(MouseMove m){
        if(!camera.mouseMoveEnabled) return;
        auto x = m.pos.x;
        auto y = m.pos.y;
        auto diffX = x - middleX;
        auto diffY = y - middleY;
        if((diffX != 0 || diffY != 0) && useMouse){
            m.reposition.set(middleX, middleY);
            m.applyReposition=true;
            camera.mouseLook( diffX,  diffY);
        }
        mousecoords.set(x, y);
    }    

    void onKey(KeyboardEvent k) {
        if (k.pressed) {
            if (k.SdlSym == SDLK_F2) {
                useMouse = !useMouse;
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
            if (k.SdlSym == SDLK_k) {
                camera.setPosition(camera.getPosition() + vec3d(0.0, 0.0, 1000.0));
            }
        }
    }

    override GuiEventResponse onDumpEvent(InputEvent e) {
        if (auto m = cast(MouseMove) e) {
            mouseMove(m);
            return GuiEventResponse.Accept;
        } else if (auto k = cast(KeyboardEvent)e) {
            auto key = k.SdlSym;
            auto down = k.pressed;
            keyMap[key] = down;
            onKey(k);
            return GuiEventResponse.Accept;
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
        double speed = 10.0;
        speed *= dTime;
        speed *= camera.speed;
        if(keyPressed(SDLK_LSHIFT)) speed *= 30;
        if(keyPressed(SDLK_a)){ camera.relativeAxisMove(-speed, 0.0, 0.0); }
        if(keyPressed(SDLK_d)){ camera.relativeAxisMove( speed, 0.0, 0.0); }
        if(keyPressed(SDLK_w)){ camera.relativeAxisMove( 0.0, speed, 0.0); }
        if(keyPressed(SDLK_s)){ camera.relativeAxisMove( 0.0,-speed, 0.0); }
        if(keyPressed(SDLK_SPACE)){ camera.relativeAxisMove( 0.0, 0.0, speed); }
        if(keyPressed(SDLK_LCTRL)){ camera.relativeAxisMove( 0.0, 0.0,-speed); }
    }
}


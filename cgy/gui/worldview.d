module gui.worldview;

import std.conv;
import std.exception;

import graphics.image;

import gui.mainmenu;
import gui.all;
import gui.guisystem.button;
//import worldgen.worldgen;
//import worldgen.newgen;
import util.util;
import util.rect;


import worldgen.maps;


class WorldMenu : GuiElementWindow {
    GuiElement guiSystem;
    MainMenu main;

    GuiElementImage heightImg;
    GuiElementImage moistureImg;
    GuiElementImage temperatureImg;

    GuiElementImage windImg;
    GuiElementImage rainImg;

    Rectd oldPos;

    World world;

    this(MainMenu m) {
        main = m;
        guiSystem = m.getGuiSystem();


        super(guiSystem, Rectd(vec2d(0.0, 0.0), vec2d(1, 1)), "World experiment Menu~~~!", false, false);

        heightImg = new GuiElementImage(this, Rectd(0, 0, 0.3, 0.3));
        moistureImg = new GuiElementImage(this, Rectd(0.3, 0, 0.3, 0.3));
        temperatureImg = new GuiElementImage(this, Rectd(0.6, 0, 0.3, 0.3));

        windImg = new GuiElementImage(this, Rectd(0, 0.3, 0.3, 0.3));
        rainImg = new GuiElementImage(this, Rectd(0.3, 0.3, 0.3, 0.3));

        heightImg.mouseClickCB = &zoomImage;
        moistureImg.mouseClickCB = &zoomImage;
        temperatureImg.mouseClickCB = &zoomImage;

        windImg.mouseClickCB = &zoomImage;
        rainImg.mouseClickCB = &zoomImage;


        world = new World;
        world.init();

        new GuiElementButton(this, Rectd(vec2d(0.75, 0.55), vec2d(0.2, 0.10)), "Back", &onBack);

        redraw(true);

    }

    override void destroy() {
        super.destroy();
    }

    bool zoomImage(GuiElement e, GuiEvent.MouseClick mc) {
        if(!mc.down || !mc.left) return false;
        if(e.widthOf == 0.3) {
            oldPos = e.getRelativeRect;
            e.setRelativeRect(Rectd(0, 0, 0.6, 0.6));
            e.bringToFront();
        } else {
            e.setRelativeRect(oldPos);
        }
        return true;
    };


    void redraw(bool all) {
        if(all) {
            heightImg.setImage(world.heightMap.toImage(0, 1, true, (double v) {
                double[4] ret;
                ret[] = v;
                if(v < 0.3) ret[0..1] = 0;
                return ret;
            }));

            temperatureImg.setImage(world.temperatureMap.toImage(0, 200, true));
        }
    }

    void onBack() {
        main.setVisible(true);
        destroy();
    }    

    override void render() {
        super.render();
    }

    override GuiEventResponse onEvent(GuiEvent e) {
        if (e.type == GuiEventType.MouseClick) {
            /*
            auto m = e.mouseClick;
            if (m.left && m.down) {
                size_t stop = determineCharPos(m.pos);
                startMarker = stop;
                stopMarker = stop;
                selecting = true;
            }
            //TODO: Add checking so that we pressed down inside this editbox as well.
            if (m.left && !m.down) {
                selecting = false;                
            }
            */
            msg("derp");
        }

        return super.onEvent(e);
    }
}




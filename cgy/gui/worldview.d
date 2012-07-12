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

import random.catmullrom;
import random.randsource;


import statistics;
import worldgen.maps;


class WorldMenu : GuiElementWindow {
    GuiElement guiSystem;
    MainMenu main;

    GuiElementImage heightImg;
    GuiElementImage moistureImg;
    GuiElementImage temperatureImg;

    GuiElementImage windImg;
    GuiElementImage rainImg;

    GuiElementImage displayImg;
    Image tmpImg;

    Image biomeMap;

    bool zoomed;
    Rectd oldPos;

    World world;
    int seed;

    this(MainMenu m) {
        main = m;
        guiSystem = m.getGuiSystem();


        super(guiSystem, Rectd(vec2d(0.0, 0.0), vec2d(1, 1)), "World experiment Menu~~~!", false, false);

        heightImg = new GuiElementImage(this, Rectd(clientArea.leftOf, clientArea.topOf, 0.3, 0.3));
        temperatureImg = new GuiElementImage(this, Rectd(heightImg.rightOf, heightImg.topOf, 0.3, 0.3));
        moistureImg = new GuiElementImage(this, Rectd(temperatureImg.rightOf, temperatureImg.topOf, 0.3, 0.3));

        windImg = new GuiElementImage(this, Rectd(heightImg.leftOf, heightImg.bottomOf, 0.3, 0.3));
        rainImg = new GuiElementImage(this, Rectd(windImg.rightOf, windImg.topOf, 0.3, 0.3));
        displayImg = new GuiElementImage(this, Rectd(rainImg.rightOf, rainImg.topOf, 0.3, 0.3));

        heightImg.mouseClickCB = &zoomImage;
        moistureImg.mouseClickCB = &zoomImage;
        temperatureImg.mouseClickCB = &zoomImage;

        windImg.mouseClickCB = &zoomImage;
        rainImg.mouseClickCB = &zoomImage;
        displayImg.mouseClickCB = &zoomImage;
        tmpImg = Image(null, Dim, Dim);

        biomeMap = Image("biomeMap.bmp");


        world = new World;
        world.init();

        auto button = new GuiElementButton(this, Rectd(vec2d(0.75, 0.75), vec2d(0.2, 0.10)), "Back", &onBack);

        auto seedEdit = new GuiElementLabeledEdit(this, Rectd(windImg.leftOf, windImg.bottomOf, 0.2, 0.05), "seed", to!string(world.worldSeed));
        seedEdit.setOnEnter((string value) {
            seed = to!int(value);
            redraw(true);
        });

        auto randomButton = new GuiElementButton(this, Rectd(seedEdit.leftOf, seedEdit.bottomOf, 0.2, 0.10), "Random", {
            auto rand = new RandSourceUniform(seed);
            seed = rand.get(int.min, int.max);
            seedEdit.setText(to!string(seed));
            redraw(true);
        });

        auto saveImagesButton = new GuiElementButton(this, Rectd(randomButton.leftOf, randomButton.bottomOf, 0.2, 0.1), "Save images", {
            heightImg.saveImage("worldview_height.bmp");
            temperatureImg.saveImage("worldview_temperature.bmp");
            moistureImg.saveImage("worldview_moisture.bmp");
            windImg.saveImage("worldview_wind.bmp");
            rainImg.saveImage("worldview_rain.bmp");
        });

        auto stepButton = new GuiElementButton(this, Rectd(saveImagesButton.leftOf, saveImagesButton.bottomOf, 0.2, 0.1), "Step", {
            mixin(MeasureTime!("Time to make a step:"));
            world.step();
            redraw(false);
        });


        redraw(false);

    }

    override void destroy() {
        super.destroy();
    }

    bool zoomImage(GuiElement e, GuiEvent.MouseClick mc) {
        if(!mc.down || !mc.left) return false;
        if(e.widthOf == 0.3) {
            if(!zoomed) {
                zoomed = true;
                oldPos = e.getRelativeRect;
                e.setRelativeRect(Rectd(clientArea.leftOf, clientArea.topOf, 0.6, 0.6));
                e.bringToFront();
            }
        } else {
            zoomed = false;
            e.setRelativeRect(oldPos);
        }
        return true;
    };

    void redraw(bool regen) {
        if(regen) {
            world = new World;
            world.worldSeed = seed;
            world.init();
        }
        heightImg.setImage(world.heightMap.toImage(world.worldMin, world.worldMax, true, (double v) {
            double[4] ret;
            ret[] = v;
            if(v < 0.3) ret[0..1] = 0;
            return ret;
        }));

        temperatureImg.setImage(world.temperatureMap.toImage(-30, 50, true, colorSpline([vec3d(0, 0, 1), vec3d(0, 0, 1), vec3d(1, 1, 0), vec3d(1, 0, 0), vec3d(1, 0, 0)])));

        windImg.setImage(world.windMap.toImage(0.0, 1.2, true, colorSpline([vec3d(0, 0, 1), vec3d(0, 0, 1), vec3d(1, 1, 0), vec3d(1, 0, 0), vec3d(1, 0, 0)])));

        moistureImg.setImage(world.moistureMap.toImage(-10, 100, true));
        rainImg.setImage(world.rainMap.toImage(-10, 100, true));

        foreach(x, y, ref r, ref g, ref b, ref a ; tmpImg) {
            auto height = world.heightMap.get(x, y);
            if(height <= 0) {
                r = g = a = 0;
                b = 96;
                continue;
            }
            auto moisture = world.moistureMap.get(x, y);
            auto temp = world.temperatureMap.get(x, y);

            int heightIdx = clamp(cast(int)(height*4 / world.worldMax), 0, 3);
            int tempIdx = clamp(cast(int)((temp-world.temperatureMin)*8 / world.temperatureRange), 0, 3);
            int moistIdx = clamp(cast(int)(moisture*4.0/10.0), 0, 3);
            //msg(tempIdx, " ", temp-world.temperatureMin);
            
            biomeMap.getPixel(3-tempIdx, 3-moistIdx, r, g, b, a);

        }
        displayImg.setImage(tmpImg);



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




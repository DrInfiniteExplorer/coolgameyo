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
    GuiElement creator;


    WorldMap worldMap;
    int seed;

    this(GuiElement _creator) {
        creator = _creator;
        guiSystem = creator.getGuiSystem();


        super(guiSystem, Rectd(vec2d(0.0, 0.0), vec2d(1, 1)), "World Mapexperiment Menu~~~!", false, false);

        worldMap = new WorldMap(880127);
        worldMap.generate();

        auto button = new PushButton(this, Rectd(vec2d(0.75, 0.75), vec2d(0.2, 0.10)), "Back", &onBack);

        auto seedEdit = new GuiElementLabeledEdit(this, Rectd(0.2, 0.2, 0.2, 0.05), "seed", to!string(worldMap.worldSeed));
        seedEdit.setOnEnter((string value) {
            seed = to!int(value);
            redraw(true);
        });

        auto randomButton = new PushButton(this, Rectd(seedEdit.leftOf, seedEdit.bottomOf, 0.2, 0.10), "Random", {
            auto rand = new RandSourceUniform(seed);
            seed = rand.get(int.min, int.max);
            seedEdit.setText(to!string(seed));
            redraw(true);
        });


        auto saveWorldButton = new PushButton(this, Rectd(randomButton.rightOf, randomButton.topOf, randomButton.widthOf, randomButton.heightOf), "Save world", {
            {
                mixin(MeasureTime!("Time to save the world(All in a days work):"));
                worldMap.save();
            }
        });



        redraw(false);

    }

    override void destroy() {
        worldMap.destroy();
        super.destroy();
    }

    void redraw(bool regen) {
        if(regen) {
            worldMap.destroy();
            worldMap = new WorldMap(seed);

            worldMap.generate();
        }
    }

    void onBack() {
        creator.setVisible(true);
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




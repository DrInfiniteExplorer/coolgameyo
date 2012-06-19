



module gui.worldview;

import std.algorithm;
import std.conv;
import std.exception;
import std.stdio;

import main;
import gui.mainmenu;
import gui.all;
//import graphics._2d.line;
import graphics.image;

//import worldgen.worldgen;
//import worldgen.voronoi;
import util.util;
import util.rect;


class WorldViewMenu : GuiElementWindow {
    GuiElement guiSystem;
    MainMenu main;
    //Voronoi voronoi;
    //Lines lines;

    this(MainMenu m) {
        main = m;
        guiSystem = m.getGuiSystem();
        
        super(guiSystem, Rectd(vec2d(0.0, 0.0), vec2d(1, 1)), "World View Menu~~~!", false, false);

        //new GuiElementButton(this, Rectd(0.1, 0.1, 0.3, 0.3), "Generate", &onGenerate);
        
        new GuiElementButton(this, Rectd(vec2d(0.75, 0.55), vec2d(0.2, 0.10)), "Back", &onBack);
        
    }
    
    override void destroy() {
        super.destroy();
    }
    
    void onBack() {
        main.setVisible(true);
        destroy();
    }

    /*

    override void render() {
        super.render();
        renderLines(lines, vec3f(0.0f));


    }

    */

    
    void onGenerate() {
        //voronoi = new Voronoi(10, 10);



    }
        
}

     


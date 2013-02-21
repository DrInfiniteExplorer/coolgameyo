



module gui.newgamemenu;

import std.conv;

import game;

import graphics.image;

import gui.all;
import gui.mainmenu;
import gui.worldview;

import json;
import util.pos;

import settings;
import statistics;
//import worldgen.worldgen;
//import worldgen.newgen;
import worldgen.maps;
//import worldgen.mapviz;
import util.filesystem;
import util.rect;
import util.util;

import gui.newgame.page1;
import gui.newgame.page2;
import gui.newgame.page3;
import gui.newgame.page4;

class NewGameMenu : GuiElementWindow {
    GuiElement guiSystem;
    MainMenu main;

    mixin Page1;
    mixin Page2;


//    string worldName;

    this(MainMenu m) {
        main = m;
        guiSystem = m.getGuiSystem();
        
        super(guiSystem, Rectd(0.0, 0.0, 1, 1), "New Game Menu~~~!", false, false);

        initPage1();

    }

    override void setVisible(bool enable) {
        super.setVisible(enable);
        if(enable) {
            initPage1();
        }
    }

 

    void onPrev() {
        if(page2.isVisible) {
            page1.setVisible(true);
            page2.setVisible(false);
        } else {
            //Harr!
        }
    }
    
    override void destroy() {
        super.destroy();
    }

    
    void onBack() {
        main.setVisible(true);
        destroy();
    }    
    void onResumeGame() {
        if(exists(g_worldPath)) {
            msg("WARNING: " ~ g_worldPath ~ " exists. Terminating the previous existance!");
            rmdir(g_worldPath);
        }
        copy("saves/" ~ gameName, g_worldPath); //Will keep old save until we exit deliberately or somehow else.
        destroy();
        main.done = true;
        main.server = true;
    }    

    void onNewGame() {
        if(page1.isVisible) {
            page1.setVisible(false);
            initPage2();
        }
    }
    void onNewWorld() {
        setVisible(false);
        new WorldMenu(this);
    }

}

     


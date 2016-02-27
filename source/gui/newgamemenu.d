



module gui.newgamemenu;

import std.algorithm : canFind;
import std.conv;

import game;

import graphics.image;

import gui.all;
import gui.mainmenu;
import gui.worldview;

import cgy.json;
import cgy.util.pos;

import settings;
import cgy.util.statistics;
//import worldgen.worldgen;
//import worldgen.newgen;
import worldgen.maps;
//import worldgen.mapviz;
import cgy.util.filesystem;
import cgy.util.rect;
import cgy.util.util;

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
        auto saves = enumerateSaves();

        if(canFind(saves, worldName)) {
            new DialogBox(this, "Eliminate all life?", "A game already exists in what world.\nTerminate all life and start again?",
                          "yes", &onNewGameYES,
                          "no", { },
                          );
        } else {
            onNewGameYES();
        }
    }
    void onNewGameYES() {
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

     






module gui.newgamemenu;

import std.conv;

import main;

import graphics.image;

import gui.all;
import gui.mainmenu;
import gui.worldview;

import pos;

import settings;
import statistics;
//import worldgen.worldgen;
//import worldgen.newgen;
import worldgen.maps;
//import worldgen.mapviz;
import util.util;
import util.rect;

import gui.newgame.page1;
import gui.newgame.page2;
import gui.newgame.page3;
import gui.newgame.page4;

class NewGameMenu : GuiElementWindow {
    GuiElement guiSystem;
    MainMenu main;

    mixin Page1;
    mixin Page2;


    string worldName;

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

 
    void onNext() {

        if(page1.isVisible) {
            auto name = worldList.getItemText(worldSelected);
            page1.setVisible(false);
            initPage2(name);
        } else if(page2.isVisible) {
            page2.setVisible(false);
        } else {
            //Start game yo!
            destroy();
            BREAKPOINT;
        }
    }

    void onPrev() {
        if(page2.isVisible) {
            page1.setVisible(true);
            page2.setVisible(false);
        } /*else if(page3.isVisible) {
            page2.setVisible(true);
            page3.setVisible(false);
        } */else {
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
    void onStartGame() {
        destroy();
        main.onNewGame(startPos, worldMap.worldHash);
    }    
    
}

     


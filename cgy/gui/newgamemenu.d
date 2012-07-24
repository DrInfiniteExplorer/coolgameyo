



module gui.newgamemenu;

import std.conv;

import main;

import graphics.image;

import gui.all;
import gui.mainmenu;
import gui.worldview;

import settings;
//import worldgen.worldgen;
//import worldgen.newgen;
import worldgen.maps;
import util.util;
import util.rect;

class NewGameMenu : GuiElementWindow {
    GuiElement guiSystem;
    MainMenu main;


    GuiElement page1;
    GuiElement page2;
    GuiElement page3;

    GuiElementText worldListLabel;
    GuiElementListBox worldList;
    GuiElementImage worldImage;



    int worldSelected = -1;

    this(MainMenu m) {
        main = m;
        guiSystem = m.getGuiSystem();
        
        super(guiSystem, Rectd(0.0, 0.0, 1, 1), "New Game Menu~~~!", false, false);

        page1 = new GuiElement(this);
        page1.setRelativeRect(Rectd(0, 0, 1, 1));
        page2 = new GuiElement(this);
        page2.setRelativeRect(Rectd(0, 0, 1, 1));
        page2.setVisible(false);
        page3 = new GuiElement(this);
        page3.setRelativeRect(Rectd(0, 0, 1, 1));
        page3.setVisible(false);

        initPage1();

    }

    void noWorldsAvailable() {
        setEnabled(false);
        new DialogBox(this, "No worlds avaiable", "Sorry, there are no worlds avaiable. Create one or cancel?",
                      "yes", &newWorld,
                      "no", { onBack(); },
                      "wtf?", { noWorldsAvailable(); }
                      );
        /*
        new DialogBox(this, "No worlds avaiable", "Sorry, there are no worlds avaiable. Create one or cancel?", "yes|no|wtf?", (string choice) {
            setEnabled(true);
            if(choice == "yes") {
                setVisible(false);
                new WorldMenu(this);
            }else if(choice == "no") {
                onBack();
            } else {
                noWorldsAvailable();
            }
        });
        */
    }

    void initPage1() {
        auto worlds = World.enumerateSavedWorlds();
        if(worlds.length == 0) {
            noWorldsAvailable();
            return;
        }
        page1.setVisible(true);
        page1.bringToFront();
        worldListLabel = new GuiElementText(page1, vec2d(0.1, 0.1), "List of generated worlds");
        worldList = new GuiElementListBox(page1, Rectd(worldListLabel.leftOf, worldListLabel.bottomOf + 0.5 * worldListLabel.heightOf, 0.3, 0.5), 18, &onSelectWorld);
        foreach(world ; worlds) {
            worldList.addItem(world);
        }

        worldImage = new GuiElementImage(page1, Rectd(worldList.rightOf, worldList.topOf, worldList.widthOf, worldList.widthOf * renderSettings.widthHeightRatio));

        auto backButton = new GuiElementButton(page1, Rectd(worldList.leftOf, worldList.bottomOf + 0.05, 0.2, 0.1), "Back", &onBack);
        auto newWorldButton = new GuiElementButton(page1, Rectd(backButton.rightOf, backButton.topOf, backButton.widthOf, backButton.heightOf), "New World", &newWorld);
        auto continueButton = new GuiElementButton(page1, Rectd(newWorldButton.rightOf, newWorldButton.topOf, newWorldButton.widthOf, newWorldButton.heightOf), "Next", &onNext);

        msg("Populate list of worlds to play on");
        msg("Select world #1");
    }

    override void setVisible(bool enable) {
        super.setVisible(enable);
        if(enable) {
            initPage1();
        }
    }

    void newWorld() {
        setVisible(false);
        new WorldMenu(this);
    }

    void onNext() {
        if(page1.isVisible) {
            page1.setVisible(false);
            page2.setVisible(true);
        } else if(page2.isVisible) {
            page2.setVisible(false);
            page3.setVisible(true);
        } else {
            //Start game yo!
            destroy();
            BREAKPOINT;
        }
    }
    
    override void destroy() {
        super.destroy();
    }

    void onSelectWorld(int idx) {
        worldSelected = idx;
        if(idx == -1) {
            
        } else {
            auto name = worldList.getItemText(worldSelected);
            worldImage.setImage(Image("worlds/" ~ name ~ "/map.tga"));
        }
    }
    
    void onBack() {
        main.setVisible(true);
        destroy();
    }    
    void onStart() {
        destroy();
        main.onNewGame();
    }    
    
}

     


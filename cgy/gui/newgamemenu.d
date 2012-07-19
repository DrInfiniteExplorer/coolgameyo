



module gui.newgamemenu;

import std.conv;

import main;
import gui.all;
import gui.mainmenu;
import gui.worldview;

import settings;
//import worldgen.worldgen;
import worldgen.newgen;
import util.util;
import util.rect;

class NewGameMenu : GuiElementWindow {
    GuiElement guiSystem;
    MainMenu main;



    GuiElementText worldListLabel;
    GuiElementListBox worldList;


    int worldSelected = -1;

    this(MainMenu m) {
        main = m;
        guiSystem = m.getGuiSystem();
        
        super(guiSystem, Rectd(0.0, 0.0, 1, 1), "New Game Menu~~~!", false, false);

        init();

    }

    void noWorldsAvailable() {
        setEnabled(false);
        new DialogBox(this, "No worlds avaiable", "Sorry, there are no worlds avaiable. Create one or cancel?",
                      "yes", { setVisible(false); new WorldMenu(this); },
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

    void init() {
        bool hasNoWorlds = true;
        if(hasNoWorlds) {
            noWorldsAvailable();
        }
        worldListLabel = new GuiElementText(this, vec2d(0.1, 0.1), "List of generated worlds");
        worldList = new GuiElementListBox(this, Rectd(worldListLabel.leftOf, worldListLabel.bottomOf + 0.5 * worldListLabel.heightOf, 0.3, 0.5), 18, &onSelectWorld);
        msg("Populate list of worlds to play on");
        msg("Select world #1");
    }

    override void setVisible(bool enable) {
        super.setVisible(enable);
        if(enable) {
            init();
        }
    }
    
    override void destroy() {
        super.destroy();
    }

    void onSelectWorld(int idx) {
        worldSelected = idx;
        if(idx == -1) {
            
        } else {
            
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

     


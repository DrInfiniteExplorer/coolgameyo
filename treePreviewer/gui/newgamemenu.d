



module gui.newgamemenu;

import std.conv;

import main;
import gui.mainmenu;
import gui.all;
import settings;
//import worldgen.worldgen;
import worldgen.newgen;
import util.util;
import util.rect;

class NewGameMenu : GuiElementWindow {
    GuiElement guiSystem;
    MainMenu main;

    GuiElementText seedText;
    
    this(MainMenu m) {
        main = m;
        guiSystem = m.getGuiSystem();
        
        super(guiSystem, Rectd(vec2d(0.0, 0.0), vec2d(1, 1)), "New Game Menu~~~!", false, false);

        auto seedLabel = new GuiElementText(this, vec2d(0.1, 0.1), "World seed");
        auto sizeLabel = new GuiElementText(this, vec2d(0.1, seedLabel.getRelativeRect().getBottom()+0.025), "World size");
        
        auto seedButton = new GuiElementEditbox(this, Rectd(vec2d(seedLabel.getRelativeRect.getRight()+0.025, 0.1), vec2d(0.2, 0.04)), "42");
        seedButton.setNumbersOnly(true);

        new GuiElementButton(this, Rectd(vec2d(0.65, 0.55), vec2d(0.2, 0.10)), "Start", &onStart);
        new GuiElementButton(this, Rectd(vec2d(0.75, 0.55), vec2d(0.2, 0.10)), "Back", &onBack);
    }
    
    override void destroy() {
        super.destroy();
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

     


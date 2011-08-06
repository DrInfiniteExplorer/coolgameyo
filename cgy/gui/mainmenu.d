

module gui.mainmenu;

import std.conv;

import derelict.sdl.sdl;

import main;
import game;
import graphics._2d.rect;
import gui.all;
import gui.unitcontrol;
import gui.optionmenu;
import gui.randommenu;
import gui.newgamemenu;
import settings;

class MainMenu : GuiElementWindow {
    Main main;
    Game game;
    GuiSystem guiSystem;
    GuiElementButton newGameButton;
    GuiElementButton resumeGameButton;
    HyperUnitControlInterfaceInputManager userControl;
    this(GuiSystem g, Main m) {
        guiSystem = g;
        super(guiSystem, Rectd(vec2d(0.1, 0.1), vec2d(0.8, 0.8)), "Main Menu~~~!", false, false);
//*
        auto text = new GuiElementText(this, vec2d(0.1, 0.1), "CoolGameYo!!");     
        auto text2 = new GuiElementText(this, vec2d(0.1, 0.2), "Where logic comes to die");
        newGameButton = new GuiElementButton(this, Rectd(vec2d(0.1, 0.2), vec2d(0.3, 0.2)), "New gay me?", &onNewGame);
  
        auto optionsButt = new GuiElementButton(this, Rectd(vec2d(0.1, 0.4), vec2d(0.3, 0.2)), "Options", &onOptions);

        auto randomButt = new GuiElementButton(this, Rectd(vec2d(0.1, 0.6), vec2d(0.3, 0.2)), "Random", &onRandom);
        auto startNewButt = new GuiElementButton(this, Rectd(vec2d(0.1, randomButt.getRelativeRect().getBottom()+0.05), vec2d(0.3, 0.2)), "newgamemenu", &onStartNewGame);
        
        //        auto cb = new GuiElementCheckBox(this, Rectd(vec2d(0.10, 0.6), vec2d(0.3, 0.2)), "CHECKBOX", null);
//*/
        main = m;
    }
    
    override void destroy() {
        super.destroy();
    }    
        
    void onNewGame(bool down, bool abort) {
        if(down || abort) {
            return;
        }
        auto rect = newGameButton.getRelativeRect();
        void loadDone() {
            userControl = new HyperUnitControlInterfaceInputManager(game, guiSystem);
            resumeGameButton = new GuiElementButton(this, rect, "Resume gay me?", &onResumeGame);
            onResumeGame(false, false);
        }
        game = main.startGame(&loadDone);
        newGameButton.destroy();
        newGameButton = null;
        
    }

    void onResumeGame(bool down, bool abort) {
        if(down || abort) {
            return;
        }
        setVisible(false);
        guiSystem.addHotkey(SDLK_ESCAPE, &enterMenu);
        guiSystem.setEventDump(userControl);
        ushort middleX = cast(ushort)renderSettings.windowWidth/2;
        ushort middleY = cast(ushort)renderSettings.windowHeight/2;
        SDL_WarpMouse(middleX, middleY);
    }
    
    void onRandom(bool down, bool abort) {
        if(down || abort) {
            return;
        }
        setVisible(false);
        new RandomMenu(this);
    }
    
    void onStartNewGame(bool down, bool abort) {
        if (down || abort) {
            return;
        }
        setVisible(false);
        new NewGameMenu(this);
    }
    
    void enterMenu() {
        setVisible(true);
        guiSystem.removeHotkey(SDLK_ESCAPE);
        guiSystem.setEventDump(null);
    }
    

    void onOptions(bool down, bool abort) {
        if(down || abort) {
            return;
        }
        new OptionMenu(this);
        setVisible(false);
    }
    
    
}

     



module gui.mainmenu;

import std.conv;

import derelict.sdl.sdl;

import main;
import game;
import graphics._2d.rect;
import gui.all;
import gui.loadscreen;
import gui.newgamemenu;
import gui.optionmenu;
import gui.randommenu;
import gui.unitcontrol;
import settings;

class MainMenu : GuiElementWindow {
    Main main;
    Game game;
    GuiSystem guiSystem;
    GuiElementButton newGameButton;
    GuiElementButton resumeGameButton;
    GuiElementButton saveGameButton;
    GuiElementButton loadGameButton;
    HyperUnitControlInterfaceInputManager userControl;
    LoadScreen loadScreen;
    this(GuiSystem g, Main m) {
        guiSystem = g;
        super(guiSystem, Rectd(vec2d(0.1, 0.1), vec2d(0.8, 0.8)), "Main Menu~~~!", false, false);
//*
        auto text = new GuiElementText(this, vec2d(0.1, 0.1), "CoolGameYo!!");     
        auto text2 = new GuiElementText(this, vec2d(0.1, 0.2), "Where logic comes to die");
        newGameButton = new GuiElementButton(this, Rectd(vec2d(0.1, 0.2), vec2d(0.3, 0.2)), "New gay me?", &onNewGame);
  
        auto optionsButt = new GuiElementButton(this, Rectd(vec2d(0.1, 0.4), vec2d(0.3, 0.2)), "Options", &onOptions);

        auto randomButt = new GuiElementButton(this, Rectd(vec2d(0.1, 0.6), vec2d(0.3, 0.2)), "Random", &onRandom);
        auto loadGameButt = new GuiElementButton(this, Rectd(vec2d(randomButt.getRelativeRect().getRight()+0.05, 0.6), vec2d(0.3, 0.2)), "Load game", &onLoadGame);
        auto startNewButt = new GuiElementButton(this, Rectd(vec2d(0.1, randomButt.getRelativeRect().getBottom()+0.05), vec2d(0.3, 0.2)), "newgamemenu", &onStartNewGame);
        
        //        auto cb = new GuiElementCheckBox(this, Rectd(vec2d(0.10, 0.6), vec2d(0.3, 0.2)), "CHECKBOX", null);
//*/
        main = m;
        loadScreen = new LoadScreen(guiSystem);
    }
    
    override void destroy() {
        if (userControl !is null) {
            userControl.destroy();
            userControl = null;
        }
        super.destroy();
    }    
        
    void onNewGame(bool down, bool abort) {
        if(down || abort) {
            return;
        }
        auto rect = newGameButton.getRelativeRect();        
        loadScreen.setLoading(true);
        void loadDone() {
            loadScreen.setLoading(false);
            userControl = new HyperUnitControlInterfaceInputManager(game, guiSystem);
            resumeGameButton = new GuiElementButton(this, rect, "Resume gay me?", &onResumeGame);
            rect.start.X += rect.size.X * 2;
            saveGameButton = new GuiElementButton(this, rect, "Save gay me?", &onSaveGame);
            onResumeGame(false, false);
        }
        game = main.startGame(&loadDone);
        newGameButton.destroy();
        newGameButton = null;
        setVisible(false);        
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
    
    void onSaveGame(bool down, bool abort) {
        if(down || abort) {
            return;
        }    
        game.saveGame("Save1");
    }
    void onLoadGame(bool down, bool abort) {
        if(down || abort) {
            return;
        }    
        loadScreen.setLoading(true);
        auto rect = newGameButton.getRelativeRect();        
        void loadDone() {
            loadScreen.setLoading(false);
            userControl = new HyperUnitControlInterfaceInputManager(game, guiSystem);
            resumeGameButton = new GuiElementButton(this, rect, "Resume gay me?", &onResumeGame);
            rect.start.X += rect.size.X * 2;
            saveGameButton = new GuiElementButton(this, rect, "Save gay me?", &onSaveGame);
            onResumeGame(false, false);
        }
        game = main.loadGame("Save1", &loadDone);
        newGameButton.destroy();
        newGameButton = null;
        setVisible(false);        
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

     

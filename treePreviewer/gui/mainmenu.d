

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
import gui.splineedit;
import gui.printscreenmenu;
import gui.unitcontrol;
import settings;
import util.util;
import util.rect;

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
        auto text = new GuiElementText(this, vec2d(0.1, 0.1), "Tree Previewer!!!!!");     
        auto text2 = new GuiElementText(this, vec2d(0.1, 0.2), "Where logic comes to die");
        newGameButton = new GuiElementButton(this, Rectd(vec2d(0.1, 0.2), vec2d(0.3, 0.2)), "New gay me?", &onNewGame);
  
        auto optionsButt = new GuiElementButton(this, Rectd(vec2d(0.1, 0.4), vec2d(0.3, 0.2)), "Options", &onOptions);

        
        loadGameButton = new GuiElementButton(this, Rectd(vec2d(newGameButton.getRelativeRect().getRight()+0.05, 0.6), vec2d(0.3, 0.2)), "Load game", &onLoadGame);

        main = m;
        loadScreen = new LoadScreen(guiSystem);


        void printScreen() {
            new PrintScreenMenu(this, game.getWorld, game.getCamera);
        }
        guiSystem.addHotkey(SDLK_PRINT, &printScreen);
    }
    
    override void destroy() {
        if (userControl !is null) {
            userControl.destroy();
            userControl = null;
        }
        super.destroy();
    }    
        
    void onNewGame() {
        auto rect = newGameButton.getRelativeRect();        
        loadScreen.setLoading(true);
        void loadDone() {
            loadScreen.setLoading(false);
            userControl = new HyperUnitControlInterfaceInputManager(game, guiSystem);
            resumeGameButton = new GuiElementButton(this, rect, "Resume gay me?", &onResumeGame);
            rect.start.X += rect.size.X * 2;
            saveGameButton = new GuiElementButton(this, rect, "Save gay me?", &onSaveGame);
            onResumeGame();
        }
        game = main.startGame(&loadDone);
        newGameButton.destroy();
        newGameButton = null;
        loadGameButton.destroy();
        loadGameButton = null;
        setVisible(false);        
    }

    void onResumeGame() {
        setVisible(false);
        guiSystem.addHotkey(SDLK_ESCAPE, &enterMenu);
        guiSystem.setEventDump(userControl);
        ushort middleX = cast(ushort)renderSettings.windowWidth/2;
        ushort middleY = cast(ushort)renderSettings.windowHeight/2;
        SDL_WarpMouse(middleX, middleY);
    }
    
    void onSaveGame() {
        
        loadScreen.setLoading(true);
        game.saveGame("Save1", { loadScreen.setLoading(false); } );
    }
    void onLoadGame() {
        loadScreen.setLoading(true);
        auto rect = newGameButton.getRelativeRect();        
        void loadDone() {
            loadScreen.setLoading(false);
            userControl = new HyperUnitControlInterfaceInputManager(game, guiSystem);
            resumeGameButton = new GuiElementButton(this, rect, "Resume gay me?", &onResumeGame);
            rect.start.X += rect.size.X * 2;
            saveGameButton = new GuiElementButton(this, rect, "Save gay me?", &onSaveGame);
            onResumeGame();
        }
        game = main.loadGame("Save1", &loadDone);
        newGameButton.destroy();
        newGameButton = null;
        loadGameButton.destroy();
        loadGameButton = null;
        setVisible(false);        
    }
    
    void onRandom() {
        setVisible(false);
        new RandomMenu(this);
    }
    void onColorSplineEdit() {
        setVisible(false);
        new SplineEditor(this);
    }
    
    void onStartNewGame() {
        setVisible(false);
        new NewGameMenu(this);
    }
    
    void enterMenu() {
        setVisible(true);
        guiSystem.removeHotkey(SDLK_ESCAPE);
        guiSystem.setEventDump(null);
    }
    

    void onOptions() {
        new OptionMenu(this);
        setVisible(false);
    }
    
    
}

     

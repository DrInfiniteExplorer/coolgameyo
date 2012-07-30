

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
import gui.random.menu;
import gui.splineedit;
import gui.printscreenmenu;
import gui.worldview;
import gui.unitcontrol;
import settings;
import util.util;
import util.rect;

class MainMenu : GuiElementWindow {
    Main main;
    Game game;
    GuiSystem guiSystem;
    PushButton newGameButton;
    PushButton resumeGameButton;
    PushButton saveGameButton;
    PushButton loadGameButton;
    HyperUnitControlInterfaceInputManager userControl;
    LoadScreen loadScreen;
    this(GuiSystem g, Main m) {
        guiSystem = g;
        super(guiSystem, Rectd(0.1, 0.1 , 0.8, 0.8), "Main Menu~~~!", false, false);
//*
        auto text = new GuiElementText(this, vec2d(0.1, 0.1), "CoolGameYo!!");     
        auto text2 = new GuiElementText(this, vec2d(0.1, 0.2), "Where logic comes to die");
        newGameButton = new PushButton(this, Rectd(0.1, 0.2, 0.3, 0.2), "New gay me?", &onNewGame);
  
        auto optionsButt = new PushButton(this, Rectd(0.1, 0.4, 0.3, 0.2), "Options", &onOptions);

        auto randomButt = new PushButton(this, Rectd(0.1, 0.6, 0.3, 0.2), "Random", &onRandom);
        auto startNewButt = new PushButton(this, Rectd(0.1, randomButt.bottomOf+0.05, 0.3, 0.2), "newgamemenu", &onStartNewGame);
        
        loadGameButton = new PushButton(this, Rectd(randomButt.rightOf+0.05, 0.6, 0.3, 0.2), "Load game", &onLoadGame);
        auto viewButt = new PushButton(this, Rectd(loadGameButton.rightOf, 0.6, 0.3, 0.2), "WorldState View", &onWorldView);

        new PushButton(this, Rectd(viewButt.leftOf, viewButt.bottomOf, viewButt.widthOf, viewButt.heightOf), "Color spline editor", &onColorSplineEdit);

        main = m;
        loadScreen = new LoadScreen(guiSystem);


        void printScreen() {
            new PrintScreenMenu(this);
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
        new DialogBox(this, "NO!", "You can't do this right now :(", "Ok :(", (){ onStartNewGame(); });
        return;
        /*
        auto rect = newGameButton.getRelativeRect();        
        loadScreen.setLoading(true);
        void loadDone() {
            loadScreen.setLoading(false);
            userControl = new HyperUnitControlInterfaceInputManager(game, guiSystem);
            resumeGameButton = new PushButton(this, rect, "Resume gay me?", &onResumeGame);
            rect.start.X += rect.size.X * 2;
            saveGameButton = new PushButton(this, rect, "Save gay me?", &onSaveGame);
            onResumeGame();
        }
        //game = main.startGame(&loadDone);
        newGameButton.destroy();
        newGameButton = null;
        loadGameButton.destroy();
        loadGameButton = null;
        setVisible(false);        
        */
    }

    void onResumeGame() {
        setVisible(false);
        guiSystem.addHotkey(SDLK_ESCAPE, &enterMenu);
        guiSystem.setEventDump(userControl);
        ushort middleX = cast(ushort)renderSettings.windowWidth/2;
        ushort middleY = cast(ushort)renderSettings.windowHeight/2;
        SDL_WarpMouse(middleX, middleY);
    }
    
    void onLoadGame() {
        new DialogBox(this, "NO!", "You can't do this right now :(", "Ok :(", (){ onStartNewGame(); });
        /*
        loadScreen.setLoading(true);
        auto rect = newGameButton.getRelativeRect();        
        void loadDone() {
            loadScreen.setLoading(false);
            userControl = new HyperUnitControlInterfaceInputManager(game, guiSystem);
            resumeGameButton = new PushButton(this, rect, "Resume gay me?", &onResumeGame);
            rect.start.X += rect.size.X * 2;
            saveGameButton = new PushButton(this, rect, "Save gay me?", &onSaveGame);
            onResumeGame();
        }
        game = main.loadGame("Save1", &loadDone);
        newGameButton.destroy();
        newGameButton = null;
        loadGameButton.destroy();
        loadGameButton = null;
        setVisible(false);        
        */
    }
    
    void onRandom() {
        setVisible(false);
        new RandomMenu(this);
    }
    void onWorldView() {
        setVisible(false);
        new WorldMenu(this);
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

     

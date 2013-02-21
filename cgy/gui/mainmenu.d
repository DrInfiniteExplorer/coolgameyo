

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
import gui.random.randommenu;
import gui.splineedit;
import gui.printscreenmenu;
import gui.worldview;
import gui.unitcontrol;
import settings;
import util.util;
import util.rect;

class MainMenu : GuiElementWindow {
    
    bool done = false;
    bool server = false;
    string host = null;

    Game game;
    GuiSystem guiSystem;
    PushButton HostButton;
    PushButton JoinButton;
    PushButton OptionsButton;
    PushButton ExitButton;


    HyperUnitControlInterfaceInputManager userControl;
    LoadScreen loadScreen;
    this(GuiSystem g) {
        guiSystem = g;
        super(guiSystem, Rectd(0.1, 0.1 , 0.8, 0.8), "CoolGameYo", false, false);

        auto width = 0.3;
        auto startX = 0.5 - width / 2.0;

        auto height = 0.15;

        auto text = new GuiElementText(this, vec2d(0.1, 0.1), "CoolGameYo!!");     
        auto text2 = new GuiElementText(this, vec2d(0.1, 0.2), "Where logic comes to die");
        
        HostButton = new PushButton(this, Rectd(startX, 0.1, width, height), "Host", &onHostGame);
        JoinButton = new PushButton(this, Rectd(startX, 0.3, width, height), "Join", &onJoinGame);
        OptionsButton = new PushButton(this, Rectd(startX, 0.5, width, height), "Options", &onOptions);
        ExitButton = new PushButton(this, Rectd(startX, 0.7, width, height), "Exit", &onExitGame);

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

    //Not called
    void onNewGame(vec2i startPos, string worldName) {

        auto rect = HostButton.getRelativeRect();        
        loadScreen.setLoading(true);
        void loadDone() {
            loadScreen.setLoading(false);
            userControl = new HyperUnitControlInterfaceInputManager(game, guiSystem);
            //resumeGameButton = new PushButton(this, rect, "Resume gay me?", &onResumeGame);
            rect.start.X += rect.size.X * 2;
            onResumeGame();
        }
//        game = startGame(startPos, worldName, &loadDone);
        //newGameButton.destroy();
        //newGameButton = null;
        //loadGameButton.destroy();
        //loadGameButton = null;
        setVisible(false);        
    }

    //Not called
    void onResumeGame() {
        setVisible(false);
        guiSystem.addHotkey(SDLK_ESCAPE, &enterMenu);
        guiSystem.setEventDump(userControl);
        ushort middleX = cast(ushort)renderSettings.windowWidth/2;
        ushort middleY = cast(ushort)renderSettings.windowHeight/2;
        SDL_WarpMouse(middleX, middleY);
    }
    
    void onLoadGame() {
        //new DialogBox(this, "NO!", "You can't do this right now :(", "Ok :(", (){ onStartNewGame(); });
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
        game = loadGame("Save1", &loadDone);
        newGameButton.destroy();
        newGameButton = null;
        loadGameButton.destroy();
        loadGameButton = null;
        setVisible(false);        
        */
    }
    
    void onHostGame() {
        g_isServer = true;
        g_worldPath = "saves/server";
        setVisible(false);
        new NewGameMenu(this);
    }
    
    void onJoinGame() {
        g_isServer = false;
        g_worldPath = "saves/client";
        host = "127.0.0.1";
        done = true;
    }
    
    void onOptions() {
        new OptionMenu(this);
        setVisible(false);
    }

    void onExitGame() {
        done = true;
        //the main menu message loop will find this. Since no saves/current, will exit.
    }
    
    void enterMenu() {
        setVisible(true);
        guiSystem.removeHotkey(SDLK_ESCAPE);
        guiSystem.setEventDump(null);
    }

}

     

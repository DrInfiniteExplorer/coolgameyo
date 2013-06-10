

module gui.mainmenu;

import std.conv;

import derelict.sdl.sdl;

import main;
import game;
import globals : g_isServer, g_worldPath;
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
    bool exit = false;
    bool server = false;
    string host = null;

    GuiSystem guiSystem;
    PushButton HostButton;
    PushButton JoinButton;
    PushButton OptionsButton;
    PushButton ExitButton;

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
        setVisible(false);
        done = true;
    }
    
    void onOptions() {
        new OptionMenu(this);
        setVisible(false);
    }

    void onExitGame() {
        done = true;
        exit = true;
    }
    
    void enterMenu() {
        setVisible(true);
        guiSystem.removeHotkey(SDLK_ESCAPE);
        guiSystem.setEventDump(null);
    }

}

string mainMenu() {
    GuiSystem guiSystem;
    guiSystem = new GuiSystem;
    scope(exit) {
        guiSystem.destroy();
    }

    MainMenu mainMenu;
    mainMenu = new MainMenu(guiSystem);

    EventAndDrawLoop!true(guiSystem, null, { return mainMenu.done; } );
    if(mainMenu.server) {
        return "host";
    }
    if(!mainMenu.exit) { // -> logic like this -> if just closing window -> exit.
        return "join";
    }
    return "exit";
}



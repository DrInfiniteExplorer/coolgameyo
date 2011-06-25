

module gui.mainmenu;

import std.conv;

import derelict.sdl.sdl;

import main;

import game;

import graphics._2d.rect;

import gui.unitcontrol;
import gui.optionmenu;
import gui.guisystem.guisystem;
import gui.guisystem.window;
import gui.guisystem.text;
import gui.guisystem.button;
import gui.guisystem.checkbox;

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
        newGameButton = new GuiElementButton(this, Rectd(vec2d(0.1, 0.3), vec2d(0.3, 0.3)), "New gay me?", &onNewGame);
  
        auto optionsButt = new GuiElementButton(this, Rectd(vec2d(0.1, 0.6), vec2d(0.3, 0.3)), "Options", &onOptions);
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
        game = main.startGame();
        userControl = new HyperUnitControlInterfaceInputManager(game);
        newGameButton.destroy();
        newGameButton = null;
        resumeGameButton = new GuiElementButton(this, Rectd(vec2d(0.1, 0.3), vec2d(0.3, 0.3)), "Resume gay me?", &onResumeGame);
        
        onResumeGame(false, false);
    }

    void onResumeGame(bool down, bool abort) {
        if(down || abort) {
            return;
        }
        setVisible(false);
        guiSystem.addHotkey(SDLK_ESCAPE, &enterMenu);
        guiSystem.setEventDump(userControl);
        auto middleX = cast(ushort)renderSettings.windowWidth/2;
        auto middleY = cast(ushort)renderSettings.windowHeight/2;
        SDL_WarpMouse(middleX, middleY);
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

     

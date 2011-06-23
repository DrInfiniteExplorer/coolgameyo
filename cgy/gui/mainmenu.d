

module gui.mainmenu;

import std.conv;

import derelict.sdl.sdl;

import main;

import graphics._2d.rect;

import gui.optionmenu;
import gui.guisystem.guisystem;
import gui.guisystem.window;
import gui.guisystem.text;
import gui.guisystem.button;
import gui.guisystem.checkbox;

class MainMenu : GuiElementWindow {
    Main main;
    GuiSystem guiSystem;
    GuiElementButton newGameButton;
    GuiElementButton resumeGameButton;
    this(GuiSystem g, Main m) {
        guiSystem = g;
        super(guiSystem, Rectd(vec2d(0.1, 0.1), vec2d(0.8, 0.8)), "Main Menu~~~!", true, true);
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
        main.startGame();
        setVisible(false);
        newGameButton.destroy();
        newGameButton = null;
        resumeGameButton = new GuiElementButton(this, Rectd(vec2d(0.1, 0.3), vec2d(0.3, 0.3)), "Resume gay me?", &onResumeGame);
        
        addEscapeHotkey();
    }

    void onResumeGame(bool down, bool abort) {
        if(down || abort) {
            return;
        }
        addEscapeHotkey();
        setVisible(false);
    }
    void addEscapeHotkey() {
        guiSystem.addHotkey(SDLK_ESCAPE, {setVisible(true); guiSystem.removeHotkey(SDLK_ESCAPE);});
    }
    

    void onOptions(bool down, bool abort) {
        if(down || abort) {
            return;
        }
        new OptionMenu(this);
        setVisible(false);
    }
    
    
}

     
